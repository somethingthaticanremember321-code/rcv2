import 'package:flutter/material.dart';

import '../models/household.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/paywall_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final PaywallService _paywallService = PaywallService();

  late Household _household;
  late TextEditingController _nameController;
  late String _currentLang;

  final List<Map<String, String>> _gccCurrencies = [
    {
      'code': 'QAR',
      'symbol': 'ر.ق',
      'nameAr': 'ريال قطري',
      'nameEn': 'Qatari Riyal',
      'flag': '🇶🇦',
    },
    {
      'code': 'SAR',
      'symbol': 'ر.س',
      'nameAr': 'ريال سعودي',
      'nameEn': 'Saudi Riyal',
      'flag': '🇸🇦',
    },
    {
      'code': 'AED',
      'symbol': 'د.إ',
      'nameAr': 'درهم إماراتي',
      'nameEn': 'UAE Dirham',
      'flag': '🇦🇪',
    },
    {
      'code': 'KWD',
      'symbol': 'د.ك',
      'nameAr': 'دينار كويتي',
      'nameEn': 'Kuwaiti Dinar',
      'flag': '🇰🇼',
    },
    {
      'code': 'OMR',
      'symbol': 'ر.ع',
      'nameAr': 'ريال عماني',
      'nameEn': 'Omani Rial',
      'flag': '🇴🇲',
    },
    {
      'code': 'BHD',
      'symbol': 'د.ب',
      'nameAr': 'دينار بحريني',
      'nameEn': 'Bahraini Dinar',
      'flag': '🇧🇭',
    },
  ];

  @override
  void initState() {
    super.initState();
    _household = _db.getHousehold();
    _currentLang = _db.appLanguage;
    _nameController = TextEditingController(text: _household.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _changeLanguage(String newLang) async {
    if (_currentLang == newLang) return;
    setState(() {
      _currentLang = newLang;
    });
    await _db.setAppLanguage(newLang);
  }

  void _saveHouseholdName() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) return;
    final updated = _household.copyWith(name: trimmed);
    await _db.updateHousehold(updated);
    setState(() {
      _household = updated;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _currentLang == 'ar' ? 'تم حفظ اسم الأسرة بنجاح' : 'Household name saved successfully',
        ),
        backgroundColor: AppTheme.primaryTeal,
      ),
    );
  }

  void _selectCurrency(Map<String, String> c) async {
    final updated = _household.copyWith(
      currencyCode: c['code']!,
      currencySymbol: c['symbol']!,
    );
    await _db.updateHousehold(updated);
    setState(() {
      _household = updated;
    });
  }

  void _exportTransactions() async {
    final isArabic = _currentLang == 'ar';
    if (!_paywallService.canExportData) {
      final upgraded = await PaywallScreen.show(context, trigger: 'settings_export');
      if (upgraded != true) return;
    }

    final transactions = _db.getTransactions();
    if (transactions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'لا توجد معاملات مسجلة للتصدير.' : 'No transactions recorded to export.',
          ),
          backgroundColor: AppTheme.terracotta,
        ),
      );
      return;
    }

    final categories = {for (var c in _db.getCategories()) c.id: c};
    final members = {for (var m in _db.getMembers()) m.id: m};
    final csv = ExportService().generateTransactionsCsv(
      household: _household,
      transactions: transactions,
      categories: categories,
      members: members,
    );

    final filename = 'mali_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    await ExportService().shareCsv(
      csvContent: csv,
      filename: filename,
      subject: isArabic
          ? 'تقرير معاملات ${_household.name}'
          : '${_household.name} Transactions Export',
    );
  }

  void _relaunchOnboarding() async {
    final isArabic = _currentLang == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isArabic ? 'إعادة التقييم المالي للأسرة؟' : 'Re-run Financial Diagnostic?',
          style: AppTheme.editorialHeading(fontSize: 18, lang: _currentLang),
        ),
        content: Text(
          isArabic
              ? 'سيفتح هذا المعالج الشامل لتحديث الدخل، الالتزامات الثابتة، والاشتراكات.'
              : 'This will launch the comprehensive assessment to update income, fixed bills, and subscriptions.',
          style: AppTheme.body(fontSize: 13, lang: _currentLang),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            child: Text(isArabic ? 'بدء التقييم' : 'Start Diagnostic'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _db.resetOnboardingForTesting();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _currentLang == 'ar';
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.creamBg,
        appBar: AppBar(
          backgroundColor: AppTheme.creamBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            isArabic ? 'الإعدادات والملف' : 'Settings & Profile',
            style: AppTheme.brandTitle(lang: _currentLang),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // SECTION 1: LANGUAGE SELECTION
              _buildSectionHeader(
                icon: Icons.language_rounded,
                title: isArabic ? 'لغة التطبيق المعتمدة' : 'App Language',
                isArabic: isArabic,
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  children: [
                    _buildLanguageTile(
                      title: 'العربية',
                      subtitle: 'واجهة متكاملة باللغة العربية مع دعم اليمين لليسار',
                      langCode: 'ar',
                      isSelected: isArabic,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildLanguageTile(
                      title: 'English',
                      subtitle: 'Full English interface with standard currency formatting',
                      langCode: 'en',
                      isSelected: !isArabic,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // SECTION 2: HOUSEHOLD PROFILE & CURRENCY
              _buildSectionHeader(
                icon: Icons.home_rounded,
                title: isArabic ? 'بيانات الأسرة والعملة' : 'Household & Currency',
                isArabic: isArabic,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Household Name Field
                    Text(
                      isArabic ? 'اسم الأسرة' : 'Household Name',
                      style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _currentLang),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.bold, lang: _currentLang),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppTheme.surfaceMuted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveHouseholdName,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isArabic ? 'حفظ' : 'Save'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Currency Picker
                    Text(
                      isArabic ? 'العملة الخليجية الحالية' : 'Active GCC Currency',
                      style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: _currentLang),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _gccCurrencies.map((c) {
                        final isSelected = _household.currencyCode == c['code'];
                        return InkWell(
                          onTap: () => _selectCurrency(c),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryTealLight : AppTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(c['flag']!, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                  isArabic ? '${c['code']} (${c['symbol']})' : '${c['code']}',
                                  style: AppTheme.body(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppTheme.primaryTeal : AppTheme.inkPrimary,
                                    lang: _currentLang,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // SECTION 3: RE-RUN FINANCIAL DIAGNOSTIC
              _buildSectionHeader(
                icon: Icons.assessment_outlined,
                title: isArabic ? 'خطة الأسرة والميزانية' : 'Financial Plan & Budgets',
                isArabic: isArabic,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isArabic
                          ? 'يمكنك إعادة إجراء التقييم المالي الشامل لتحديث الدخل الشهري، الالتزامات، والاشتراكات في أي وقت.'
                          : 'Re-run the full financial assessment anytime to update monthly income, fixed bills, and subscriptions.',
                      style: AppTheme.body(fontSize: 13, color: AppTheme.inkSecondary, lang: _currentLang),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _relaunchOnboarding,
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryTeal, size: 18),
                      label: Text(
                        isArabic ? 'إعادة التقييم المالي الشامل' : 'Re-run Financial Diagnostic',
                        style: AppTheme.body(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTeal,
                          lang: _currentLang,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryTealBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // SECTION 4: DATA EXPORT & PRIVACY
              _buildSectionHeader(
                icon: Icons.shield_outlined,
                title: isArabic ? 'البيانات والخصوصية' : 'Data & Sovereignty',
                isArabic: isArabic,
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _paywallService.isPro,
                      builder: (context, isPro, _) {
                        if (isPro) {
                          return ListTile(
                            leading: const Icon(Icons.workspace_premium_rounded, color: AppTheme.accentGold),
                            title: Text(
                              isArabic ? 'عضوية مالي برو: نشطة' : 'Mali Pro: Active',
                              style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.bold, lang: _currentLang),
                            ),
                            subtitle: Text(
                              isArabic
                                  ? 'اشتراكك نشط عبر Google Play'
                                  : 'Subscription active via Google Play',
                              style: AppTheme.body(fontSize: 11, color: AppTheme.inkSecondary, lang: _currentLang),
                            ),
                            trailing: const Icon(Icons.check_circle_rounded, color: AppTheme.accentGold),
                          );
                        }
                        return ListTile(
                          leading: const Icon(Icons.workspace_premium_outlined, color: AppTheme.primaryTeal),
                          title: Text(
                            isArabic ? 'باقة مالي: الباقة المجانية' : 'Mali Tier: Free Basic',
                            style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.bold, lang: _currentLang),
                          ),
                          subtitle: Text(
                            isArabic
                                ? 'الترقية إلى مالي برو للميزات المتقدمة وتتبع الثروة'
                                : 'Upgrade to Mali Pro for advanced wealth & analytics',
                            style: AppTheme.body(fontSize: 11, color: AppTheme.inkSecondary, lang: _currentLang),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTealLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isArabic ? 'ترقية' : 'Upgrade',
                              style: AppTheme.body(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTeal,
                                lang: _currentLang,
                              ),
                            ),
                          ),
                          onTap: () => PaywallScreen.show(context, trigger: 'settings_tier_tile'),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined, color: AppTheme.primaryTeal),
                      title: Text(
                        isArabic ? 'تصدير المعاملات (إكسل / CSV)' : 'Export Transactions (Excel / CSV)',
                        style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.bold, lang: _currentLang),
                      ),
                      subtitle: Text(
                        isArabic ? 'تصدير فوري مشفر بتنسيق UTF-8 BOM' : 'Instant UTF-8 BOM formatted spreadsheet',
                        style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: _currentLang),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _exportTransactions,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined, color: AppTheme.accentGold),
                      title: Text(
                        isArabic ? 'أمان محلي ١٠٠٪ بدون ربط بنوك' : '100% Local Offline Privacy',
                        style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.bold, lang: _currentLang),
                      ),
                      subtitle: Text(
                        isArabic ? 'بياناتك محفوظة على جهازك فقط' : 'Encrypted solely on your device',
                        style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: _currentLang),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Version Badge
              Center(
                child: Text(
                  isArabic ? 'مالي - الإصدار 1.0.12' : 'Mali — Version 1.0.12',
                  style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: _currentLang),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required bool isArabic,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryTeal, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTheme.label(fontSize: 13, color: AppTheme.inkPrimary, lang: _currentLang),
        ),
      ],
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required String subtitle,
    required String langCode,
    required bool isSelected,
  }) {
    return ListTile(
      onTap: () => _changeLanguage(langCode),
      title: Text(
        title,
        style: AppTheme.body(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryTeal : AppTheme.inkPrimary,
          lang: langCode,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: langCode),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTeal)
          : const Icon(Icons.radio_button_unchecked, color: AppTheme.surfaceBorder),
    );
  }
}
