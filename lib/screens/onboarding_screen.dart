import 'package:flutter/material.dart';

import '../data/subscription_catalog.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final DatabaseService _db = DatabaseService();
  final PageController _pageController = PageController();

  int _currentPage = 0;
  static const int _totalPages = 5;

  // STEP 1: Language & GCC Identity
  String _selectedLang = 'ar';
  String _selectedCurrencyCode = 'QAR';
  String _selectedCurrencySymbol = 'ر.ق';
  final TextEditingController _householdNameController = TextEditingController();

  // STEP 2: Inflows (Income) & Contributors
  final TextEditingController _primaryIncomeController = TextEditingController();
  final TextEditingController _secondaryIncomeController = TextEditingController();
  final TextEditingController _primaryMemberController = TextEditingController();
  final TextEditingController _secondaryMemberController = TextEditingController();

  // STEP 3: Fixed Commitments
  final TextEditingController _housingController = TextEditingController();
  final TextEditingController _utilitiesController = TextEditingController();
  final TextEditingController _groceriesController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _helperController = TextEditingController();

  // STEP 4: GCC Subscription Radar (100+ Curated Catalog & Custom Subscriptions)
  late List<SubscriptionCatalogItem> _subscriptions;
  final TextEditingController _subSearchController = TextEditingController();
  String _selectedCategoryFilter = 'all';

  final List<Map<String, String>> _subscriptionCategories = const [
    {'id': 'all', 'nameEn': 'All (100+)', 'nameAr': 'الكل (+١٠٠)'},
    {'id': 'streaming', 'nameEn': 'Streaming', 'nameAr': 'ترفيه وبث'},
    {'id': 'food_delivery', 'nameEn': 'Food & Delivery', 'nameAr': 'توصيل ومطاعم'},
    {'id': 'music', 'nameEn': 'Music', 'nameAr': 'موسيقى'},
    {'id': 'cloud_telecom', 'nameEn': 'Cloud & Telco', 'nameAr': 'اتصالات وسحابيات'},
    {'id': 'ai_tech', 'nameEn': 'AI & Tech', 'nameAr': 'ذكاء اصطناعي وتقنية'},
    {'id': 'gaming', 'nameEn': 'Gaming', 'nameAr': 'ألعاب'},
    {'id': 'fitness', 'nameEn': 'Fitness & Health', 'nameAr': 'رياضة وصحة'},
    {'id': 'kids_edu', 'nameEn': 'Learning & Kids', 'nameAr': 'تعليم وأطفال'},
    {'id': 'news_business', 'nameEn': 'News & Business', 'nameAr': 'أخبار وأعمال'},
    {'id': 'home_auto', 'nameEn': 'Auto & Home', 'nameAr': 'سيارات ومنزل'},
  ];

  final List<Map<String, String>> _gccCurrencies = [
    {
      'code': 'QAR',
      'symbol': 'ر.ق',
      'nameAr': 'ريال قطري',
      'nameEn': 'Qatari Riyal',
      'flag': '🇶🇦',
      'countryAr': 'قطر',
      'countryEn': 'Qatar',
    },
    {
      'code': 'SAR',
      'symbol': 'ر.س',
      'nameAr': 'ريال سعودي',
      'nameEn': 'Saudi Riyal',
      'flag': '🇸🇦',
      'countryAr': 'السعودية',
      'countryEn': 'Saudi Arabia',
    },
    {
      'code': 'AED',
      'symbol': 'د.إ',
      'nameAr': 'درهم إماراتي',
      'nameEn': 'UAE Dirham',
      'flag': '🇦🇪',
      'countryAr': 'الإمارات',
      'countryEn': 'UAE',
    },
    {
      'code': 'KWD',
      'symbol': 'د.ك',
      'nameAr': 'دينار كويتي',
      'nameEn': 'Kuwaiti Dinar',
      'flag': '🇰🇼',
      'countryAr': 'الكويت',
      'countryEn': 'Kuwait',
    },
    {
      'code': 'OMR',
      'symbol': 'ر.ع',
      'nameAr': 'ريال عماني',
      'nameEn': 'Omani Rial',
      'flag': '🇴🇲',
      'countryAr': 'عُمان',
      'countryEn': 'Oman',
    },
    {
      'code': 'BHD',
      'symbol': 'د.ب',
      'nameAr': 'دينار بحريني',
      'nameEn': 'Bahraini Dinar',
      'flag': '🇧🇭',
      'countryAr': 'البحرين',
      'countryEn': 'Bahrain',
    },
  ];

  @override
  void initState() {
    super.initState();
    try {
      final h = _db.getHousehold();
      _selectedLang = _db.appLanguage;
      _selectedCurrencyCode = h.currencyCode;
      _selectedCurrencySymbol = h.currencySymbol;
      _householdNameController.text = h.name;
    } catch (_) {
      _selectedLang = 'ar';
      _householdNameController.text = 'عائلتنا';
    }

    if (_householdNameController.text.isEmpty || _householdNameController.text == 'Our Household' || _householdNameController.text == 'عائلتنا') {
      _householdNameController.text = _selectedLang == 'ar' ? 'عائلتنا' : 'Our Household';
    }

    _primaryMemberController.text = _selectedLang == 'ar' ? 'أنا' : 'Self';
    _secondaryMemberController.text = _selectedLang == 'ar' ? 'الزوج / الزوجة' : 'Spouse';

    // Reasonable defaults for quick frictionless entry
    _primaryIncomeController.text = '20000';
    _housingController.text = '6000';
    _utilitiesController.text = '1000';
    _groceriesController.text = '3500';

    _subscriptions = getDefaultSubscriptionCatalog();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _householdNameController.dispose();
    _primaryIncomeController.dispose();
    _secondaryIncomeController.dispose();
    _primaryMemberController.dispose();
    _secondaryMemberController.dispose();
    _housingController.dispose();
    _utilitiesController.dispose();
    _groceriesController.dispose();
    _schoolController.dispose();
    _helperController.dispose();
    _subSearchController.dispose();
    super.dispose();
  }

  void _switchLanguage(String newLang) {
    if (_selectedLang == newLang) return;
    setState(() {
      _selectedLang = newLang;
      if (newLang == 'en') {
        if (_householdNameController.text == 'عائلتنا') {
          _householdNameController.text = 'Our Household';
        }
        if (_primaryMemberController.text == 'أنا') {
          _primaryMemberController.text = 'Self';
        }
        if (_secondaryMemberController.text == 'الزوج / الزوجة') {
          _secondaryMemberController.text = 'Spouse';
        }
      } else {
        if (_householdNameController.text == 'Our Household') {
          _householdNameController.text = 'عائلتنا';
        }
        if (_primaryMemberController.text == 'Self') {
          _primaryMemberController.text = 'أنا';
        }
        if (_secondaryMemberController.text == 'Spouse') {
          _secondaryMemberController.text = 'الزوج / الزوجة';
        }
      }
    });
  }

  double _parseVal(TextEditingController c) {
    final clean = c.text.replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  double get _totalInflows => _parseVal(_primaryIncomeController) + _parseVal(_secondaryIncomeController);

  double get _totalFixedCommitments {
    return _parseVal(_housingController) +
        _parseVal(_utilitiesController) +
        _parseVal(_groceriesController) +
        _parseVal(_schoolController) +
        _parseVal(_helperController);
  }

  double get _totalSubscriptions {
    return _subscriptions
        .where((s) => s.isSelected)
        .fold(0.0, (sum, item) => sum + item.cost);
  }

  int get _selectedSubscriptionsCount => _subscriptions.where((s) => s.isSelected).length;

  List<SubscriptionCatalogItem> get _filteredSubscriptions {
    final query = _subSearchController.text.trim().toLowerCase();
    return _subscriptions.where((item) {
      final matchesCategory = _selectedCategoryFilter == 'all' || item.category == _selectedCategoryFilter;
      if (!matchesCategory) return false;

      if (query.isEmpty) return true;
      final nameEnMatch = item.nameEn.toLowerCase().contains(query);
      final nameArMatch = item.nameAr.toLowerCase().contains(query);
      final catEnMatch = item.categoryEn.toLowerCase().contains(query);
      final catArMatch = item.categoryAr.toLowerCase().contains(query);
      return nameEnMatch || nameArMatch || catEnMatch || catArMatch;
    }).toList();
  }

  double get _unallocatedSurplus => _totalInflows - _totalFixedCommitments - _totalSubscriptions;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeAssessment();
    }
  }

  void _completeAssessment() async {
    final fixedMap = <String, double>{
      if (_parseVal(_housingController) > 0) 'housing': _parseVal(_housingController),
      if (_parseVal(_utilitiesController) > 0) 'utilities': _parseVal(_utilitiesController),
      if (_parseVal(_groceriesController) > 0) 'groceries': _parseVal(_groceriesController),
      if (_parseVal(_schoolController) > 0) 'school': _parseVal(_schoolController),
      if (_parseVal(_helperController) > 0) 'domestic_help': _parseVal(_helperController),
    };

    final selectedSubs = _subscriptions.where((s) => s.isSelected).map((s) => s.toMap()).toList();

    await _db.applyOnboardingFinancialAssessment(
      language: _selectedLang,
      currencyCode: _selectedCurrencyCode,
      currencySymbol: _selectedCurrencySymbol,
      householdName: _householdNameController.text.trim().isEmpty
          ? (_selectedLang == 'ar' ? 'عائلتنا' : 'Our Household')
          : _householdNameController.text.trim(),
      primaryMemberName: _primaryMemberController.text.trim().isEmpty
          ? (_selectedLang == 'ar' ? 'أنا' : 'Self')
          : _primaryMemberController.text.trim(),
      secondaryMemberName: _secondaryMemberController.text.trim().isEmpty ? null : _secondaryMemberController.text.trim(),
      primaryMonthlyIncome: _parseVal(_primaryIncomeController),
      secondaryMonthlyIncome: _parseVal(_secondaryIncomeController),
      fixedCommitments: fixedMap,
      selectedSubscriptions: selectedSubs,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(
          key: ValueKey('main_nav_$_selectedLang'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _selectedLang == 'ar';
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.creamBg,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar: Step Indicator & Skip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Step Progress Dots
                    Row(
                      children: List.generate(_totalPages, (index) {
                        final isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          height: 6,
                          width: isActive ? 28 : 6,
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),

                    // Skip action (pages 0-3)
                    if (_currentPage < _totalPages - 1)
                      TextButton(
                        onPressed: _completeAssessment,
                        child: Text(
                          isArabic ? 'تخطي للرئيسية' : 'Skip to Home',
                          style: AppTheme.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.inkMuted,
                            lang: _selectedLang,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 36),
                  ],
                ),
              ),

              // Page Views
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: [
                    _buildStep1LanguageAndCurrency(isArabic),
                    _buildStep2HouseholdInflows(isArabic),
                    _buildStep3FixedCommitments(isArabic),
                    _buildStep4SubscriptionRadar(isArabic),
                    _buildStep5FinancialSummary(isArabic),
                  ],
                ),
              ),

              // Bottom Navigation Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Row(
                  children: [
                    if (_currentPage > 0) ...[
                      OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.surfaceBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Icon(
                          isArabic ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                          color: AppTheme.inkPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    Expanded(
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _totalPages - 1
                                  ? (isArabic ? 'اعتماد الميزانية وبدء التطبيق' : 'Confirm Budget & Launch')
                                  : (isArabic ? 'متابعة الخطوة التالية' : 'Continue to Next Step'),
                              style: AppTheme.body(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                lang: _selectedLang,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _totalPages - 1
                                  ? Icons.check_circle_rounded
                                  : (isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded),
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // --- STEP 1: LANGUAGE & GCC IDENTITY ---
  // ==========================================
  Widget _buildStep1LanguageAndCurrency(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryTeal, Color(0xFF0A4E3D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.account_balance_rounded, size: 36, color: AppTheme.accentGold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'التقييم المالي لأسرة أهل' : 'Ahl Family Financial Assessment',
            style: AppTheme.editorialHeading(fontSize: 22, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'لنبدأ بتحديد لغتك، عملتك الخليجية، واسم عائلتك الكريمة.'
                : 'Let us start by setting your language, GCC currency, and family name.',
            style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Bilingual Toggle
          Text(
            isArabic ? 'لغة التطبيق' : 'App Language',
            style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _switchLanguage('ar'),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isArabic ? AppTheme.primaryTeal : AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isArabic ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'العربية',
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isArabic ? Colors.white : AppTheme.inkPrimary,
                        lang: 'ar',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _switchLanguage('en'),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !isArabic ? AppTheme.primaryTeal : AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !isArabic ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'English',
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: !isArabic ? Colors.white : AppTheme.inkPrimary,
                        lang: 'en',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Currency Chips
          Text(
            isArabic ? 'العملة الخليجية' : 'GCC Currency',
            style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _gccCurrencies.map((c) {
              final isSelected = _selectedCurrencyCode == c['code'];
              final country = isArabic ? c['countryAr']! : c['countryEn']!;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCurrencyCode = c['code']!;
                    _selectedCurrencySymbol = c['symbol']!;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryTealLight : AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c['flag']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${c['code']} • $country',
                        style: AppTheme.body(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryTeal : AppTheme.inkPrimary,
                          lang: _selectedLang,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Household Name
          Text(
            isArabic ? 'اسم الأسرة' : 'Household Name',
            style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _householdNameController,
            style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.bold, lang: _selectedLang),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceCard,
              hintText: isArabic ? 'مثال: عائلتنا، أسرة آل ثاني' : 'e.g. Our Household',
              prefixIcon: const Icon(Icons.home_rounded, color: AppTheme.primaryTeal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // --- STEP 2: HOUSEHOLD INFLOWS (INCOME) ---
  // ==========================================
  Widget _buildStep2HouseholdInflows(bool isArabic) {
    final currency = isArabic ? _selectedCurrencySymbol : _selectedCurrencyCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            isArabic ? 'إجمالي الدخل والتدفقات الشهرية' : 'Monthly Household Inflows',
            style: AppTheme.editorialHeading(fontSize: 22, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'أدخل الرواتب والتدفقات المتوقعة لأسرتكم لتحديد السقف المالي بدقة.'
                : 'Enter your monthly earnings to map your family budget ceiling.',
            style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Primary Income
          _buildAmountField(
            controller: _primaryIncomeController,
            label: isArabic ? 'الراتب / الدخل الأساسي الشهري' : 'Primary Monthly Salary',
            hint: '20,000',
            currency: currency,
            icon: Icons.payments_outlined,
            isArabic: isArabic,
          ),

          const SizedBox(height: 16),

          // Secondary Income
          _buildAmountField(
            controller: _secondaryIncomeController,
            label: isArabic ? 'دخل إضافي / راتب الشريك (اختياري)' : 'Secondary Income / Partner (Optional)',
            hint: '0',
            currency: currency,
            icon: Icons.account_balance_wallet_outlined,
            isArabic: isArabic,
          ),

          const SizedBox(height: 20),

          // Contributor Names
          Text(
            isArabic ? 'أطراف المشاركة المالية' : 'Household Contributors',
            style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNameField(
                  controller: _primaryMemberController,
                  hint: isArabic ? 'أنا' : 'Self',
                  color: AppTheme.primaryTeal,
                  icon: Icons.person,
                  isArabic: isArabic,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildNameField(
                  controller: _secondaryMemberController,
                  hint: isArabic ? 'الزوج / الزوجة' : 'Spouse',
                  color: AppTheme.accentGold,
                  icon: Icons.favorite,
                  isArabic: isArabic,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Total Inflows Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryTealLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryTealBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'إجمالي الدخل الشهري:' : 'Total Monthly Inflow:',
                  style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal, lang: _selectedLang),
                ),
                Text(
                  AppTheme.formatMoney(
                    _totalInflows,
                    currencyCode: _selectedCurrencyCode,
                    currencySymbol: _selectedCurrencySymbol,
                    lang: _selectedLang,
                  ),
                  style: AppTheme.amountMonospace(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // --- STEP 3: FIXED COMMITMENTS ---
  // ==========================================
  Widget _buildStep3FixedCommitments(bool isArabic) {
    final currency = isArabic ? _selectedCurrencySymbol : _selectedCurrencyCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            isArabic ? 'الالتزامات الثابتة والأساسية' : 'Fixed Monthly Commitments',
            style: AppTheme.editorialHeading(fontSize: 22, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'النفقات الشهرية الحتمية التي لا مفر منها لتشغيل البيت.'
                : 'Essential monthly expenses required to run your household.',
            style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),

          _buildAmountField(
            controller: _housingController,
            label: isArabic ? 'السكن (إيجار أو قسط تمويل عقاري)' : 'Housing (Rent or Mortgage)',
            hint: '6,000',
            currency: currency,
            icon: Icons.home_outlined,
            isArabic: isArabic,
          ),
          const SizedBox(height: 12),

          _buildAmountField(
            controller: _utilitiesController,
            label: isArabic ? 'الفواتير والخدمات (كهرباء، ماء، إنترنت)' : 'Utilities (Electricity, Water, Fiber)',
            hint: '1,000',
            currency: currency,
            icon: Icons.bolt_outlined,
            isArabic: isArabic,
          ),
          const SizedBox(height: 12),

          _buildAmountField(
            controller: _groceriesController,
            label: isArabic ? 'المؤن والمقاضي التقديرية' : 'Groceries & Household Supplies',
            hint: '3,500',
            currency: currency,
            icon: Icons.shopping_cart_outlined,
            isArabic: isArabic,
          ),
          const SizedBox(height: 12),

          _buildAmountField(
            controller: _schoolController,
            label: isArabic ? 'أقساط المدارس والحضانات (شهرياً)' : 'School & Tuition (Monthly avg)',
            hint: '0',
            currency: currency,
            icon: Icons.school_outlined,
            isArabic: isArabic,
          ),
          const SizedBox(height: 12),

          _buildAmountField(
            controller: _helperController,
            label: isArabic ? 'رواتب العمالة المنزلية / السائق' : 'Domestic Help / Driver Salaries',
            hint: '0',
            currency: currency,
            icon: Icons.cleaning_services_outlined,
            isArabic: isArabic,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // --- STEP 4: GCC SUBSCRIPTION RADAR ---
  // ==========================================
  Widget _buildStep4SubscriptionRadar(bool isArabic) {
    final filtered = _filteredSubscriptions;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            isArabic ? 'رادار الاشتراكات الرقمية (+١٠٠)' : 'GCC Subscription Radar (100+)',
            style: AppTheme.editorialHeading(fontSize: 22, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'ابحث في أكثر من ١٠٠ اشتراك خليجي وعالمي، أو أضف اشتراكاً مخصصاً لكشف النزيف المالي التراكمي.'
                : 'Search 100+ subscriptions or add custom recurring spend to audit leaks.',
            style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _subSearchController,
            onChanged: (_) => setState(() {}),
            style: AppTheme.body(fontSize: 13, lang: _selectedLang),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceCard,
              hintText: isArabic
                  ? 'ابحث في الاشتراكات (نتفليكس، طلبات، جيم، شات جي بي تي...)'
                  : 'Search 100+ subscriptions (Netflix, Talabat, Gym, AI...)',
              hintStyle: AppTheme.body(fontSize: 12, color: AppTheme.inkMuted, lang: _selectedLang),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryTeal, size: 20),
              suffixIcon: _subSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _subSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action & Counter Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Selected Counter Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _selectedSubscriptionsCount > 0 ? AppTheme.accentGoldLight : AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedSubscriptionsCount > 0 ? AppTheme.accentGoldBorder : AppTheme.surfaceBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedSubscriptionsCount > 0 ? Icons.check_circle_rounded : Icons.checklist_rounded,
                      size: 14,
                      color: _selectedSubscriptionsCount > 0 ? AppTheme.accentGold : AppTheme.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isArabic
                          ? 'المحدد: $_selectedSubscriptionsCount'
                          : 'Selected: $_selectedSubscriptionsCount',
                      style: AppTheme.body(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _selectedSubscriptionsCount > 0 ? AppTheme.inkPrimary : AppTheme.inkSecondary,
                        lang: _selectedLang,
                      ),
                    ),
                  ],
                ),
              ),

              // Add Custom Subscription CTA
              InkWell(
                onTap: () => _showAddCustomSubscriptionSheet(context, isArabic),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTealLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryTealBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 15, color: AppTheme.primaryTeal),
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? 'إضافة اشتراك مخصص' : '+ Custom Subscription',
                        style: AppTheme.body(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTeal,
                          lang: _selectedLang,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Horizontal Category Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _subscriptionCategories.map((cat) {
                final isSelected = _selectedCategoryFilter == cat['id'];
                final label = isArabic ? cat['nameAr']! : cat['nameEn']!;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppTheme.inkSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryTeal,
                    backgroundColor: AppTheme.surfaceCard,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                    ),
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategoryFilter = cat['id']!);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Subscriptions Grid / Empty State
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 36, color: AppTheme.inkMuted),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? 'لم نجد اشتراكاً يطابق "${_subSearchController.text}"'
                        : 'No subscription matching "${_subSearchController.text}"',
                    style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _selectedLang),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCustomSubscriptionSheet(context, isArabic),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(
                      isArabic
                          ? 'إضافة "${_subSearchController.text}" كاشتراك مخصص'
                          : 'Add "${_subSearchController.text}" as custom',
                      style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, lang: _selectedLang),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filtered.map((sub) {
                final isSelected = sub.isSelected;
                final cost = sub.cost;
                return InkWell(
                  onTap: () {
                    setState(() {
                      sub.isSelected = !isSelected;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentGoldLight : AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accentGold : AppTheme.surfaceBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sub.icon,
                          size: 16,
                          color: isSelected ? AppTheme.accentGold : AppTheme.inkSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sub.displayName(_selectedLang),
                          style: AppTheme.body(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.inkPrimary : AppTheme.inkSecondary,
                            lang: _selectedLang,
                          ),
                        ),
                        if (sub.isCustom) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isArabic ? 'خاص' : 'Custom',
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          '~${cost.toInt()}',
                          style: AppTheme.amountMonospace(
                            fontSize: 11,
                            color: isSelected ? AppTheme.accentGold : AppTheme.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),

          // Pure Arithmetic Calculation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'تكلفة الاشتراكات شهرياً:' : 'Total Monthly Subscriptions:',
                      style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _selectedLang),
                    ),
                    Text(
                      AppTheme.formatMoney(
                        _totalSubscriptions,
                        currencyCode: _selectedCurrencyCode,
                        currencySymbol: _selectedCurrencySymbol,
                        lang: _selectedLang,
                      ),
                      style: AppTheme.amountMonospace(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'التكلفة السنوية التراكمية:' : 'Annual Cumulative Cost:',
                      style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.inkPrimary, lang: _selectedLang),
                    ),
                    Text(
                      AppTheme.formatMoney(
                        _totalSubscriptions * 12,
                        currencyCode: _selectedCurrencyCode,
                        currencySymbol: _selectedCurrencySymbol,
                        lang: _selectedLang,
                      ),
                      style: AppTheme.amountMonospace(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAddCustomSubscriptionSheet(BuildContext context, bool isArabic) {
    final nameController = TextEditingController(text: _subSearchController.text.trim());
    final costController = TextEditingController();
    IconData selectedIcon = Icons.star_rounded;

    final presetIcons = const [
      Icons.star_rounded,
      Icons.fitness_center_rounded,
      Icons.movie_outlined,
      Icons.fastfood_outlined,
      Icons.cloud_outlined,
      Icons.directions_car_outlined,
      Icons.school_outlined,
      Icons.videogame_asset_outlined,
      Icons.music_note_outlined,
      Icons.card_membership_outlined,
      Icons.pets_outlined,
      Icons.shopping_bag_outlined,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final keyboardPadding = MediaQuery.of(ctx).viewInsets.bottom;
          final currency = isArabic ? _selectedCurrencySymbol : _selectedCurrencyCode;

          return Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + keyboardPadding),
            decoration: const BoxDecoration(
              color: AppTheme.creamBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic ? 'إضافة اشتراك مخصص' : 'Add Custom Subscription',
                    style: AppTheme.editorialHeading(fontSize: 18, lang: _selectedLang),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? 'أدخل اسم الاشتراك وتكلفته الشهرية لإدراجه في حسابات النزيف المالي.'
                        : 'Enter name and monthly cost to track recurring leakage.',
                    style: AppTheme.body(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Subscription Name
                  Text(
                    isArabic ? 'اسم الاشتراك أو الخدمة' : 'Subscription / Service Name',
                    style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.bold, lang: _selectedLang),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceCard,
                      hintText: isArabic ? 'مثال: مدرب شخصي، سباحة، مدرسة لغات...' : 'e.g. Personal Trainer, Swimming Club...',
                      prefixIcon: Icon(selectedIcon, color: AppTheme.accentGold),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Monthly Cost
                  _buildAmountField(
                    controller: costController,
                    label: isArabic ? 'التكلفة الشهرية ($currency)' : 'Monthly Cost ($currency)',
                    hint: '100',
                    currency: currency,
                    icon: Icons.payments_outlined,
                    isArabic: isArabic,
                  ),
                  const SizedBox(height: 16),

                  // Icon Picker
                  Text(
                    isArabic ? 'اختر أيقونة' : 'Choose an Icon',
                    style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: presetIcons.map((ic) {
                      final isSel = selectedIcon == ic;
                      return InkWell(
                        onTap: () => setModalState(() => selectedIcon = ic),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.accentGoldLight : AppTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? AppTheme.accentGold : AppTheme.surfaceBorder,
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            ic,
                            size: 20,
                            color: isSel ? AppTheme.accentGold : AppTheme.inkSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Add CTA
                  ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final cost = double.tryParse(costController.text.replaceAll(',', '').trim()) ?? 0.0;
                      if (name.isEmpty || cost <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic ? 'يرجى إدخال اسم الاشتراك وتكلفة صالحة.' : 'Please enter a name and valid cost.',
                            ),
                            backgroundColor: AppTheme.terracotta,
                          ),
                        );
                        return;
                      }

                      final customItem = SubscriptionCatalogItem(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        nameEn: name,
                        nameAr: name,
                        cost: cost,
                        icon: selectedIcon,
                        category: 'custom',
                        categoryEn: 'Custom',
                        categoryAr: 'مخصص',
                        isSelected: true,
                        isCustom: true,
                      );

                      setState(() {
                        _subscriptions.insert(0, customItem);
                        _subSearchController.clear();
                      });

                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabic ? 'تمت إضافة "$name" إلى رادار الاشتراكات 🎉' : 'Added "$name" to subscription radar 🎉',
                          ),
                          backgroundColor: AppTheme.primaryTeal,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      isArabic ? 'إضافة الاشتراك وتفعيله' : 'Add & Activate Subscription',
                      style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, lang: _selectedLang),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // --- STEP 5: PURE DESCRIPTIVE SUMMARY ---
  // ==========================================
  Widget _buildStep5FinancialSummary(bool isArabic) {
    final surplus = _unallocatedSurplus;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            isArabic ? 'الملخص الحسابي لخطة الأسرة' : 'Household Financial Summary',
            style: AppTheme.editorialHeading(fontSize: 22, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'حساب رياضي دقيق يعكس أرقام أسرتكم الفعلية التي أدخلتموها.'
                : 'Factual arithmetic reflecting your actual entered family numbers.',
            style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _selectedLang),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),

          // Factual Breakdown Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  label: isArabic ? 'إجمالي التدفقات (الدخل)' : 'Total Inflows (Income)',
                  amount: _totalInflows,
                  color: AppTheme.primaryTeal,
                  isPositive: true,
                  isArabic: isArabic,
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: isArabic ? 'الالتزامات الأساسية الثابتة' : 'Fixed Monthly Commitments',
                  amount: _totalFixedCommitments,
                  color: AppTheme.inkPrimary,
                  isPositive: false,
                  isArabic: isArabic,
                ),
                const SizedBox(height: 10),
                _buildSummaryRow(
                  label: isArabic ? 'الاشتراكات الشهرية' : 'Subscriptions',
                  amount: _totalSubscriptions,
                  color: AppTheme.terracotta,
                  isPositive: false,
                  isArabic: isArabic,
                ),
                const Divider(height: 24, thickness: 1.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'الفائض الشهري المتاح' : 'Unallocated Monthly Buffer',
                          style: AppTheme.body(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.inkPrimary,
                            lang: _selectedLang,
                          ),
                        ),
                        Text(
                          isArabic ? 'للادخار، الاستثمار، والمصاريف اليومية' : 'For savings, investments & daily spend',
                          style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: _selectedLang),
                        ),
                      ],
                    ),
                    Text(
                      AppTheme.formatMoney(
                        surplus,
                        currencyCode: _selectedCurrencyCode,
                        currencySymbol: _selectedCurrencySymbol,
                        lang: _selectedLang,
                      ),
                      style: AppTheme.amountMonospace(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: surplus >= 0 ? AppTheme.primaryTeal : AppTheme.terracotta,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Confidence & Action Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.creamBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accentGoldBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppTheme.accentGold, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'سيتم اعتماد هذه الأرقام كميزانيات مبدئية للتصنيفات، مع إمكانية تعديلها في أي وقت.'
                        : 'These numbers will calibrate your starting category budgets, editable anytime.',
                    style: AppTheme.body(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required double amount,
    required Color color,
    required bool isPositive,
    required bool isArabic,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _selectedLang),
        ),
        Text(
          '${isPositive ? "+" : "-"} ${AppTheme.formatMoney(amount, currencyCode: _selectedCurrencyCode, currencySymbol: _selectedCurrencySymbol, lang: _selectedLang)}',
          style: AppTheme.amountMonospace(fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildAmountField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String currency,
    required IconData icon,
    required bool isArabic,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _selectedLang),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: AppTheme.amountMonospace(fontSize: 15, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceCard,
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.primaryTeal, size: 20),
            suffixText: currency,
            suffixStyle: AppTheme.label(fontSize: 12, color: AppTheme.inkMuted, lang: _selectedLang),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.surfaceBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.surfaceBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField({
    required TextEditingController controller,
    required String hint,
    required Color color,
    required IconData icon,
    required bool isArabic,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Icon(icon, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.bold, lang: _selectedLang),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: hint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
