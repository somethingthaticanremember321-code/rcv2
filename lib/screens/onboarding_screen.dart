import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'household_dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final DatabaseService _db = DatabaseService();
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  int _currentPage = 0;
  static const int _totalPages = 4;

  // Form State
  String _selectedLang = 'ar'; // 'ar' or 'en'
  final TextEditingController _householdNameController = TextEditingController(text: 'عائلتنا');
  final TextEditingController _primaryMemberController = TextEditingController(text: 'أنا');
  final TextEditingController _secondaryMemberController = TextEditingController(text: 'الزوج / الزوجة');

  String _selectedCurrencyCode = 'QAR';
  String _selectedCurrencySymbol = 'ر.ق';

  int _userRating = 5;
  bool _hasRated = false;

  final List<Map<String, String>> _gccCurrencies = [
    {'code': 'QAR', 'symbol': 'ر.ق', 'nameAr': 'ريال قطري', 'nameEn': 'Qatar Riyal'},
    {'code': 'SAR', 'symbol': 'ر.س', 'nameAr': 'ريال سعودي', 'nameEn': 'Saudi Riyal'},
    {'code': 'AED', 'symbol': 'د.إ', 'nameAr': 'درهم إماراتي', 'nameEn': 'UAE Dirham'},
    {'code': 'KWD', 'symbol': 'د.ك', 'nameAr': 'دينار كويتي', 'nameEn': 'Kuwaiti Dinar'},
    {'code': 'OMR', 'symbol': 'ر.ع', 'nameAr': 'ريال عماني', 'nameEn': 'Omani Rial'},
    {'code': 'BHD', 'symbol': 'د.ب', 'nameAr': 'دينار بحريني', 'nameEn': 'Bahraini Dinar'},
  ];

  @override
  void initState() {
    super.initState();
    final h = _db.getHousehold();
    _selectedLang = h.preferredLanguage;
    _selectedCurrencyCode = h.currencyCode;
    _selectedCurrencySymbol = h.currencySymbol;
    if (_selectedLang == 'en') {
      _householdNameController.text = 'Our Household';
      _primaryMemberController.text = 'Self';
      _secondaryMemberController.text = 'Spouse';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _householdNameController.dispose();
    _primaryMemberController.dispose();
    _secondaryMemberController.dispose();
    super.dispose();
  }

  void _onLanguageChanged(String lang) {
    setState(() {
      _selectedLang = lang;
      if (lang == 'en') {
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

  void _nextPage() {
    if (_currentPage == 1) {
      // Step 2 validation
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    // 1. Update household in DB
    final household = _db.getHousehold();
    final updated = household.copyWith(
      name: _householdNameController.text.trim().isEmpty
          ? (_selectedLang == 'ar' ? 'عائلتنا' : 'Our Household')
          : _householdNameController.text.trim(),
      currencyCode: _selectedCurrencyCode,
      currencySymbol: _selectedCurrencySymbol,
      preferredLanguage: _selectedLang,
    );
    await _db.updateHousehold(updated);

    // 2. Update members if names changed
    final members = _db.getMembers();
    if (members.isNotEmpty) {
      final primary = members.firstWhere((m) => m.isPrimary, orElse: () => members.first);
      await _db.updateMember(primary.copyWith(name: _primaryMemberController.text.trim()));

      final nonPrimary = members.where((m) => !m.isPrimary).toList();
      if (nonPrimary.isNotEmpty) {
        await _db.updateMember(nonPrimary.first.copyWith(name: _secondaryMemberController.text.trim()));
      }
    }

    // 3. Mark onboarding complete
    await _db.setHasSeenOnboarding(true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HouseholdDashboardScreen(),
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
                    // Step Dots
                    Row(
                      children: List.generate(_totalPages, (index) {
                        final isActive = index == _currentPage;
                        return Container(
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          height: 6,
                          width: isActive ? 24 : 6,
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),

                    // Skip button
                    if (_currentPage < _totalPages - 1)
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          isArabic ? 'تخطي' : 'Skip',
                          style: AppTheme.bodyMedium(
                            fontSize: 14,
                            color: AppTheme.inkMuted,
                            lang: _selectedLang,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Page View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: [
                    _buildLanguageStep(isArabic),
                    _buildHouseholdSetupStep(isArabic),
                    _buildFeaturesOverviewStep(isArabic),
                    _buildRatingStep(isArabic),
                  ],
                ),
              ),

              // Bottom Navigation Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Row(
                  children: [
                    if (_currentPage > 0) ...[
                      OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.surfaceBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Icon(
                          isArabic ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                          color: AppTheme.inkPrimary,
                          size: 18,
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          _currentPage == _totalPages - 1
                              ? (isArabic ? 'ابدأ الآن' : 'Get Started')
                              : (isArabic ? 'التالي' : 'Continue'),
                          style: AppTheme.bodyMedium(
                            fontSize: 16,
                            color: Colors.white,
                            lang: _selectedLang,
                          ),
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

  // --- STEP 1: LANGUAGE SELECTION ---
  Widget _buildLanguageStep(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryTealLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryTealBorder),
            ),
            child: const Icon(
              Icons.language_rounded,
              size: 56,
              color: AppTheme.primaryTeal,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            isArabic ? 'مرحباً بك في أهل' : 'Welcome to Ahl',
            textAlign: TextAlign.center,
            style: AppTheme.editorialHeading(fontSize: 28, lang: _selectedLang),
          ),
          const SizedBox(height: 10),
          Text(
            isArabic
                ? 'التطبيق المالي المشترك الأول المصمم خصيصاً للأسر في الخليج العربي'
                : 'The premier joint household finance and Zakat app designed for the GCC',
            textAlign: TextAlign.center,
            style: AppTheme.body(fontSize: 15, color: AppTheme.inkSecondary, lang: _selectedLang),
          ),
          const SizedBox(height: 36),

          // Question: Which language?
          Text(
            isArabic ? 'اختر لغة التطبيق المفضلة:' : 'Select your preferred language:',
            style: AppTheme.bodyMedium(fontSize: 14, lang: _selectedLang),
          ),
          const SizedBox(height: 12),

          // Arabic Option Card
          _buildLanguageOptionCard(
            title: 'العربية',
            subtitle: 'واجهة متكاملة باللغة العربية مع دعم كامل لاتجاه النص',
            langCode: 'ar',
            flag: '🇸🇦 🇶🇦 🇦🇪',
          ),
          const SizedBox(height: 12),

          // English Option Card
          _buildLanguageOptionCard(
            title: 'English',
            subtitle: 'Full English interface with GCC currency and Zakat tools',
            langCode: 'en',
            flag: '🌐',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOptionCard({
    required String title,
    required String subtitle,
    required String langCode,
    required String flag,
  }) {
    final isSelected = _selectedLang == langCode;

    return GestureDetector(
      onTap: () => _onLanguageChanged(langCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTealLight : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium(
                      fontSize: 16,
                      color: isSelected ? AppTheme.primaryTealDark : AppTheme.inkPrimary,
                      lang: langCode,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.body(fontSize: 12, color: AppTheme.inkMuted, lang: _selectedLang),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTeal, size: 22)
            else
              const Icon(Icons.circle_outlined, color: AppTheme.surfaceBorder, size: 22),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: HOUSEHOLD VALIDATION & CURRENCY ---
  Widget _buildHouseholdSetupStep(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Text(
                isArabic ? 'إعداد حساب الأسرة' : 'Setup Household',
                style: AppTheme.editorialHeading(fontSize: 24, lang: _selectedLang),
              ),
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'أدخل بيانات الأسرة لنخصص العملة والمساهمين بدقة'
                    : 'Personalize your household currency and joint contributors',
                style: AppTheme.body(fontSize: 14, color: AppTheme.inkSecondary, lang: _selectedLang),
              ),
              const SizedBox(height: 24),

              // Household Name Input with Validation
              Text(
                isArabic ? 'اسم الأسرة / الميزانية *' : 'Household Name *',
                style: AppTheme.label(fontSize: 12, lang: _selectedLang),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _householdNameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isArabic ? 'يرجى إدخال اسم الأسرة' : 'Household name cannot be empty';
                  }
                  if (value.trim().length < 2) {
                    return isArabic ? 'الاسم قصير جداً' : 'Name must be at least 2 characters';
                  }
                  return null;
                },
                style: AppTheme.body(fontSize: 15, color: AppTheme.inkPrimary, lang: _selectedLang),
                decoration: InputDecoration(
                  hintText: isArabic ? 'مثال: عائلة آل ثاني / عائلتنا' : 'e.g. Our Family',
                  filled: true,
                  fillColor: AppTheme.surfaceCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Currency Selection
              Text(
                isArabic ? 'العملة الأساسية للأسرة' : 'Primary GCC Currency',
                style: AppTheme.label(fontSize: 12, lang: _selectedLang),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _gccCurrencies.map((curr) {
                  final isSelected = _selectedCurrencyCode == curr['code'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCurrencyCode = curr['code']!;
                        _selectedCurrencySymbol = curr['symbol']!;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          Text(
                            curr['symbol']!,
                            style: AppTheme.amountMonospace(
                              fontSize: 13,
                              color: isSelected ? AppTheme.primaryTealDark : AppTheme.inkPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isArabic ? curr['nameAr']! : curr['code']!,
                            style: AppTheme.body(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppTheme.primaryTealDark : AppTheme.inkSecondary,
                              lang: _selectedLang,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Contributors Names
              Text(
                isArabic ? 'المساهمون في الميزانية المشتركة' : 'Joint Contributors',
                style: AppTheme.label(fontSize: 12, lang: _selectedLang),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _primaryMemberController,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? (isArabic ? 'مطلوب' : 'Required')
                          : null,
                      style: AppTheme.body(fontSize: 14, lang: _selectedLang),
                      decoration: InputDecoration(
                        labelText: isArabic ? 'المساهم الأول' : 'Primary Contributor',
                        labelStyle: AppTheme.label(fontSize: 11, lang: _selectedLang),
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _secondaryMemberController,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? (isArabic ? 'مطلوب' : 'Required')
                          : null,
                      style: AppTheme.body(fontSize: 14, lang: _selectedLang),
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الشريك / الزوج' : 'Spouse / Partner',
                        labelStyle: AppTheme.label(fontSize: 11, lang: _selectedLang),
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- STEP 3: FEATURES OVERVIEW ---
  Widget _buildFeaturesOverviewStep(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isArabic ? 'لماذا صُمم أهل؟' : 'Why Ahl?',
            textAlign: TextAlign.center,
            style: AppTheme.editorialHeading(fontSize: 26, lang: _selectedLang),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'ثلاث ركائز تبني الاستقرار المالي لأسرتك'
                : 'Three pillars supporting your family’s financial peace of mind',
            textAlign: TextAlign.center,
            style: AppTheme.body(fontSize: 14, color: AppTheme.inkSecondary, lang: _selectedLang),
          ),
          const SizedBox(height: 32),

          _buildFeatureCard(
            icon: Icons.people_outline_rounded,
            color: AppTheme.primaryTeal,
            title: isArabic ? 'إدارة مالية مشتركة بوضوح' : 'Joint Household Finance',
            desc: isArabic
                ? 'تسجيل سريع للنفقات لكل مساهم دون ربط بنكي قسري أو مشاركة كلمات مرور.'
                : 'Frictionless manual logging per contributor without forced bank sync.',
            lang: _selectedLang,
          ),
          const SizedBox(height: 14),

          _buildFeatureCard(
            icon: Icons.calendar_month_outlined,
            color: AppTheme.accentGold,
            title: isArabic ? 'ميزانية تفهم المواسم الخليجية' : 'GCC Seasonal Budgeting',
            desc: isArabic
                ? 'تعديل استثنائي تلقائي لميزانيات رمضان، ولائم الأعياد، والإجازات الصيفية.'
                : 'Month-specific budget overrides for Ramadan, Eid hospitality, and summer.',
            lang: _selectedLang,
          ),
          const SizedBox(height: 14),

          _buildFeatureCard(
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.primaryTealDark,
            title: isArabic ? 'حساب شرعي دقيق للزكاة' : 'Accurate Shariah Zakat',
            desc: isArabic
                ? 'تتبع دقيق للحول والنصاب (٨٥غ ذهب) وخصم الديون المستحقة شرعاً.'
                : 'Proper lunar hawl period tracking, 85g gold nisab, and debt deductions.',
            lang: _selectedLang,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required String lang,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.bodyMedium(fontSize: 15, lang: lang)),
                const SizedBox(height: 4),
                Text(desc, style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: lang)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 4: RATE THE APP ADVERTISEMENT ---
  Widget _buildRatingStep(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Star Icon illustration
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.accentGoldLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accentGoldBorder),
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 56,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            isArabic ? 'ساعد عائلات الخليج على إيجادنا!' : 'Help GCC Families Discover Ahl!',
            textAlign: TextAlign.center,
            style: AppTheme.editorialHeading(fontSize: 24, lang: _selectedLang),
          ),
          const SizedBox(height: 10),
          Text(
            isArabic
                ? 'تقييمك بـ ٥ نجوم يدعم استمرارنا وتطوير ميزات مخصصة لأسرتك مجاناً. رأيك يصنع الفرق معنا!'
                : 'Leaving a 5-star review helps us grow and keep building privacy-first family tools. Your support means everything!',
            textAlign: TextAlign.center,
            style: AppTheme.body(fontSize: 14, color: AppTheme.inkSecondary, lang: _selectedLang),
          ),
          const SizedBox(height: 28),

          // Interactive 5 Stars
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.accentGoldBorder),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGold.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starNum = index + 1;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _userRating = starNum;
                          _hasRated = true;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.star_rounded,
                          size: 38,
                          color: starNum <= _userRating ? AppTheme.accentGold : AppTheme.surfaceBorder,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  _hasRated
                      ? (isArabic ? 'شكراً لدعمك الكريم! 🤍' : 'Thank you for supporting Ahl! 🤍')
                      : (isArabic ? 'انقر على النجوم للتقييم' : 'Tap the stars to rate'),
                  style: AppTheme.bodyMedium(
                    fontSize: 13,
                    color: _hasRated ? AppTheme.primaryTeal : AppTheme.inkMuted,
                    lang: _selectedLang,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Button: Rate Now
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _hasRated = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isArabic
                        ? 'شكراً جزيلاً لتقييمك ومساندتك لتطبيق أهل!'
                        : 'Thank you for your 5-star review and support!',
                  ),
                  backgroundColor: AppTheme.primaryTeal,
                ),
              );
            },
            icon: const Icon(Icons.favorite_rounded, color: AppTheme.accentGold, size: 18),
            label: Text(
              isArabic ? 'تقييم التطبيق ⭐️⭐️⭐️⭐️⭐️' : 'Rate 5 Stars on App Store',
              style: AppTheme.bodyMedium(fontSize: 14, color: AppTheme.inkPrimary, lang: _selectedLang),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.accentGold, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
