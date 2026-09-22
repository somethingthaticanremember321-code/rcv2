import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../services/paywall_service.dart';
import '../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  final String trigger;

  const PaywallScreen({
    super.key,
    this.trigger = 'general',
  });

  /// Displays the Paywall as a modal bottom sheet
  static Future<bool?> show(
    BuildContext context, {
    String trigger = 'general',
  }) {
    AnalyticsService().paywallImpression(trigger: trigger);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaywallScreen(trigger: trigger),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final PaywallService _paywallService = PaywallService();
  final DatabaseService _db = DatabaseService();

  late Household _household;
  List<AhlSubscriptionPlan> _plans = [];
  AhlSubscriptionPlan? _selectedPlan;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _household = _db.getHousehold();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await _paywallService.getAvailablePlans(
      currencySymbol: _household.currencySymbol,
    );
    if (mounted) {
      setState(() {
        _plans = plans;
        if (_plans.isNotEmpty) {
          // Default select the annual plan if present
          _selectedPlan = _plans.firstWhere(
            (p) => p.hasTrial || p.id.contains('annual'),
            orElse: () => _plans.first,
          );
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    if (_paywallService.isProUser) {
      Navigator.of(context).pop(true);
      return;
    }
    if (_selectedPlan == null || _isPurchasing) return;

    setState(() => _isPurchasing = true);
    final success = await _paywallService.purchasePlan(_selectedPlan!);
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    if (success) {
      final isArabic = _household.preferredLanguage == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم الاشتراك بنجاح! أهلاً بك في مالي برو 🎉'
                : 'Subscribed successfully! Welcome to Mali Pro 🎉',
          ),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      final isArabic = _household.preferredLanguage == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر إتمام عملية الشراء، يرجى المحاولة مرة أخرى.'
                : 'Purchase could not be completed, please try again.',
          ),
          backgroundColor: AppTheme.terracotta,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isPurchasing = true);
    final restored = await _paywallService.restorePurchases();
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    final isArabic = _household.preferredLanguage == 'ar';
    if (restored) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'تم استعادة اشتراكك بنجاح! ✨' : 'Purchases restored successfully! ✨',
          ),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'لم يتم العثور على اشتراكات نشطة.' : 'No active subscriptions found.',
          ),
          backgroundColor: AppTheme.terracotta,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _household.preferredLanguage == 'ar';
    final lang = _household.preferredLanguage;
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.creamBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top dismiss icon row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGoldLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentGoldBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium_rounded, size: 16, color: AppTheme.accentGold),
                        const SizedBox(width: 6),
                        Text(
                          isArabic ? 'مالي برو' : 'MALI PRO',
                          style: AppTheme.body(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentGold,
                            lang: lang,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.inkSecondary),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                children: [
                  // Headline & Hero
                  Text(
                    isArabic
                        ? 'سيادة مالية ووضوح تام لمستقبلك'
                        : 'Complete Financial Sovereignty & Clarity',
                    style: AppTheme.editorialHeading(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      lang: lang,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isArabic
                        ? 'افتح كامل الميزات المتقدمة، تتبع الاشتراكات غير المحدودة، وحساب الزكاة الدقيق بخصوصية محلية ١٠٠٪.'
                        : 'Unlock all premium features, unlimited subscription tracking, and precise Zakat with 100% offline-first privacy.',
                    style: AppTheme.bodyMedium(
                      fontSize: 13,
                      color: AppTheme.inkSecondary,
                      lang: lang,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Feature Matrix
                  _buildFeatureItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: isArabic ? 'مصادر دخل ومساهمين غير محدودين' : 'Unlimited Incomes & Contributors',
                    subtitle: isArabic
                        ? 'تتبع راتبك، مصادر دخلك الجانبية، ومساهمات الأسرة أو الشركاء بلا أي سقف.'
                        : 'Track primary salary, side incomes, freelancing, and family contributors without limits.',
                    lang: lang,
                  ),
                  _buildFeatureItem(
                    icon: Icons.auto_awesome_rounded,
                    title: isArabic ? 'ميزانيات مواسم متعددة ومتزامنة' : 'Multi-Seasonal Budget Multipliers',
                    subtitle: isArabic
                        ? 'تعديلات تلقائية لمصروفات شهر رمضان المبارك، تجهيزات العيد، والإجازات الصيفية.'
                        : 'Flexible monthly multipliers for Ramadan groceries, Eid banquets, and summer travel.',
                    lang: lang,
                  ),
                  _buildFeatureItem(
                    icon: Icons.balance_rounded,
                    title: isArabic ? 'حقيبة زكاة شرعية شاملة' : 'Comprehensive Shariah Zakat Suite',
                    subtitle: isArabic
                        ? 'تقييم فوري للذهب بمختلف العيارات (١٨-٢٤)، الفضة، الأسهم، مع حسم الديون وسجل سداد معتمد.'
                        : 'Instant gold karat valuation, silver, stocks, debt deductions, and verified audit ledger.',
                    lang: lang,
                  ),
                  _buildFeatureItem(
                    icon: Icons.table_chart_outlined,
                    title: isArabic ? 'تصدير التقارير المالية (CSV / Excel)' : 'CSV & Excel Data Export',
                    subtitle: isArabic
                        ? 'تصدير السجل المالي للأسرة وحسابات الزكاة لملفات إكسل بضغطة زر وبدعم كامل للعربية.'
                        : 'One-tap spreadsheet export formatted with UTF-8 BOM for Microsoft Excel.',
                    lang: lang,
                  ),
                  _buildFeatureItem(
                    icon: Icons.shield_outlined,
                    title: isArabic ? 'خصوصية تامة بدون ربط بنكي' : '100% Offline-First Privacy',
                    subtitle: isArabic
                        ? 'سجلاتك المالية مشفرة محلياً على جهازك. لا مشاركة بيانات ولا إعلانات أبداً.'
                        : 'Your financial data never leaves your device. Zero bank passwords, zero ads.',
                    lang: lang,
                    isLast: true,
                  ),

                  const SizedBox(height: 20),

                  // Pro Active Banner when unlocked
                  ValueListenableBuilder<bool>(
                    valueListenable: _paywallService.isPro,
                    builder: (context, isPro, _) {
                      if (!isPro) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGoldLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.accentGoldBorder, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: AppTheme.accentGold, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic ? 'عضوية أهل برو نشطة لديك 🎉' : 'Ahl Pro Active 🎉',
                                      style: AppTheme.body(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.inkPrimary,
                                        lang: lang,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isArabic
                                          ? 'اشتراكك نشط عبر Google Play. جميع الميزات المتقدمة متاحة.'
                                          : 'Your subscription is active via Google Play. All premium features are unlocked.',
                                      style: AppTheme.body(
                                        fontSize: 11,
                                        color: AppTheme.inkSecondary,
                                        lang: lang,
                                      ),
                                    ),
                                  ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Subscription Plans Selector
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppTheme.primaryTeal),
                      ),
                    )
                  else
                    Column(
                      children: _plans.map((plan) {
                        final isSelected = _selectedPlan?.id == plan.id;
                        return _buildPlanCard(plan, isSelected, isArabic, lang);
                      }).toList(),
                    ),

                  // 7-Day Free Trial Timeline (Shown when trial plan selected)
                  if (_selectedPlan?.hasTrial ?? false) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTealLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, size: 16, color: AppTheme.primaryTeal),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? 'كيف تعمل التجربة المجانية (٧ أيام):' : 'How your 7-day free trial works:',
                                style: AppTheme.body(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTealDark,
                                  lang: lang,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTimelineStep(
                            step: '1',
                            title: isArabic ? 'اليوم: وصول فوري لكامل الميزات' : 'Today: Instant full Pro access',
                            desc: isArabic ? 'لن تدفع أي هللة اليوم (\$0.00).' : 'You are charged \$0.00 today.',
                            isArabic: isArabic,
                            lang: lang,
                          ),
                          _buildTimelineStep(
                            step: '2',
                            title: isArabic ? 'اليوم ٥: إشعار تذكيري مسبق' : 'Day 5: Trial reminder heads-up',
                            desc: isArabic ? 'تذكير شفاف قبل انتهاء فترة التجربة.' : 'A reminder before your trial ends.',
                            isArabic: isArabic,
                            lang: lang,
                          ),
                          _buildTimelineStep(
                            step: '3',
                            title: isArabic ? 'اليوم ٧: يبدأ الاشتراك السنوي' : 'Day 7: Annual membership begins',
                            desc: isArabic
                                ? 'يمكنك الإلغاء بأي لحظة قبل اليوم ٧ من إعدادات المتجر بلا أي رسوم.'
                                : 'Cancel anytime before Day 7 in Google Play and pay nothing.',
                            isArabic: isArabic,
                            lang: lang,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Store Reassurance
                  Center(
                    child: Text(
                      isArabic
                          ? '🔒 تجديد آمن عبر المتجر، وإلغاء فوري بضغطة واحدة بأي وقت.'
                          : '🔒 Secure store billing, cancel anytime with 1 tap.',
                      style: AppTheme.bodyMedium(
                        fontSize: 11,
                        color: AppTheme.inkMuted,
                        lang: lang,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Primary CTA Button
                  ElevatedButton(
                    onPressed: _isPurchasing ? null : _handlePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.accentGoldBorder, width: 1.5),
                      ),
                    ),
                    child: _isPurchasing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _getButtonText(isArabic),
                            style: AppTheme.body(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              lang: lang,
                            ),
                          ),
                  ),

                  const SizedBox(height: 6),

                  // Soft Skip Button (Keeps user in app on Free tier)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        isArabic ? 'المتابعة بالباقة المجانية' : 'Continue with Free Version',
                        style: AppTheme.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkSecondary,
                          lang: lang,
                        ),
                      ),
                    ),
                  ),

                  // Secondary Action: Restore Purchases
                  Center(
                    child: TextButton(
                      onPressed: _isPurchasing ? null : _handleRestore,
                      child: Text(
                        isArabic ? 'استعادة المشتريات السابقة' : 'Restore Previous Purchases',
                        style: AppTheme.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.inkMuted,
                          lang: lang,
                        ),
                      ),
                    ),
                  ),

                  // Developer Testing Sandbox Mode
                  if (kDebugMode) ...[
                    const Divider(height: 24),
                    Center(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _paywallService.isPro,
                        builder: (context, isPro, _) {
                          return ActionChip(
                            avatar: Icon(
                              isPro ? Icons.check_circle : Icons.toggle_off_outlined,
                              size: 16,
                              color: isPro ? AppTheme.accentGold : AppTheme.inkSecondary,
                            ),
                            label: Text(
                              'Developer Sandbox: ${isPro ? "PRO ACTIVE" : "FREE TIER"} (Tap to toggle)',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              _paywallService.togglePro();
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getButtonText(bool isArabic) {
    if (_paywallService.isProUser) {
      return isArabic ? 'مالي برو مفعّل — متابعة' : 'Mali Pro Active — Continue';
    }
    if (_selectedPlan?.isLifetime ?? false) {
      return isArabic ? 'امتلك مالي مدى الحياة' : 'Get Mali Lifetime Access';
    }
    if (_selectedPlan?.hasTrial ?? false) {
      return isArabic ? 'ابدأ التجربة المجانية (٧ أيام مجاناً)' : 'Start 7-Day Free Trial';
    }
    return isArabic ? 'الاشتراك في مالي برو' : 'Subscribe to Mali Pro';
  }

  Widget _buildTimelineStep({
    required String step,
    required String title,
    required String desc,
    required bool isArabic,
    required String lang,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: AppTheme.primaryTeal,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: AppTheme.primaryTeal.withValues(alpha: 0.25),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.body(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.inkPrimary,
                    lang: lang,
                  ),
                ),
                Text(
                  desc,
                  style: AppTheme.body(
                    fontSize: 11,
                    color: AppTheme.inkSecondary,
                    lang: lang,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String lang,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryTealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkPrimary,
                    lang: lang,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.bodyMedium(
                    fontSize: 12,
                    color: AppTheme.inkSecondary,
                    lang: lang,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    AhlSubscriptionPlan plan,
    bool isSelected,
    bool isArabic,
    String lang,
  ) {
    final savingsBadge = isArabic ? plan.savingsBadgeAr : plan.savingsBadgeEn;
    final title = isArabic ? plan.titleAr : plan.titleEn;
    final price = isArabic ? plan.priceDisplayAr : plan.priceDisplayEn;
    final period = isArabic ? plan.periodAr : plan.periodEn;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentGoldLight.withValues(alpha: 0.4) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentGold : AppTheme.surfaceBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.accentGold : AppTheme.inkMuted,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.inkPrimary,
                            lang: lang,
                          ),
                        ),
                      ),
                      if (savingsBadge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            savingsBadge,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    period,
                    style: AppTheme.bodyMedium(
                      fontSize: 12,
                      color: AppTheme.inkSecondary,
                      lang: lang,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: AppTheme.amountMonospace(
                fontSize: 14,
                color: AppTheme.primaryTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
