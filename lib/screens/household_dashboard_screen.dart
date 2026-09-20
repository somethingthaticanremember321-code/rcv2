import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/category.dart';
import '../models/household.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/paywall_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';
import 'quick_add_transaction_sheet.dart';
import 'settings_screen.dart';

class HouseholdDashboardScreen extends StatefulWidget {
  final VoidCallback? onToggleLanguage;

  const HouseholdDashboardScreen({
    super.key,
    this.onToggleLanguage,
  });

  @override
  State<HouseholdDashboardScreen> createState() => _HouseholdDashboardScreenState();
}

class _HouseholdDashboardScreenState extends State<HouseholdDashboardScreen> {
  final DatabaseService _db = DatabaseService();
  final PaywallService _paywallService = PaywallService();
  late DateTime _selectedMonth;
  late Household _household;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _household = _db.getHousehold();
  }

  void _reloadHousehold() {
    setState(() {
      _household = _db.getHousehold();
    });
  }

  void _toggleLanguage() async {
    final currentLang = _db.appLanguage;
    final newLang = currentLang == 'ar' ? 'en' : 'ar';
    await _db.setAppLanguage(newLang);
    _reloadHousehold();
    widget.onToggleLanguage?.call();
  }

  void _exportTransactions() async {
    final isArabic = _household.preferredLanguage == 'ar';
    if (!_paywallService.canExportData) {
      final upgraded = await PaywallScreen.show(context, trigger: 'dashboard_export');
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

    final filename = 'ahl_transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await ExportService().shareCsv(
      csvContent: csv,
      filename: filename,
      subject: isArabic
          ? 'سجل معاملات أسرة ${_household.name}'
          : '${_household.name} Household Transactions',
    );
  }

  void _changeMonth(int deltaMonths) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + deltaMonths,
        1,
      );
    });
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home_rounded;
      case 'shopping_cart':
        return Icons.shopping_bag_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'directions_car':
        return Icons.directions_car_outlined;
      case 'bolt':
        return Icons.bolt_outlined;
      case 'cleaning_services':
        return Icons.cleaning_services_outlined;
      case 'medical_services':
        return Icons.medical_services_outlined;
      case 'restaurant':
        return Icons.restaurant_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryTeal;
    }
  }

  String _formatCurrency(double amount) {
    return AppTheme.formatMoney(
      amount,
      currencyCode: _household.currencyCode,
      currencySymbol: _household.currencySymbol,
      lang: _household.preferredLanguage,
    );
  }

  String _getHouseholdDisplayName(String lang) {
    if (_household.name == 'عائلتنا' && lang == 'en') {
      return 'Our Household';
    }
    if (_household.name == 'Our Household' && lang == 'ar') {
      return 'عائلتنا';
    }
    return _household.name;
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
    final lang = _household.preferredLanguage;
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.creamBg,
        appBar: AppBar(
          backgroundColor: AppTheme.creamBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTealLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: AppTheme.primaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _getHouseholdDisplayName(lang),
                  style: AppTheme.brandTitle(lang: lang),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            // Pro Status / Upgrade Pill
            ValueListenableBuilder<bool>(
              valueListenable: _paywallService.isPro,
              builder: (context, isPro, _) {
                if (isPro) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Row(
                            children: [
                              const Icon(Icons.workspace_premium_rounded, color: AppTheme.accentGold),
                              const SizedBox(width: 8),
                              Text(
                                isArabic ? 'عضوية أهل برو' : 'Ahl Pro Membership',
                                style: AppTheme.editorialHeading(fontSize: 18, lang: lang),
                              ),
                            ],
                          ),
                          content: Text(
                            isArabic
                                ? 'عضوية أهل برو نشطة عبر Google Play. جميع ميزات المساهمين والميزانيات الموسمية وحسابات الزكاة وتصدير البيانات مفتوحة بلا حدود.'
                                : 'Ahl Pro is active via Google Play. Unlimited contributors, seasonal budgets, Zakat portfolio tracking, and instant data exports are completely available.',
                            style: AppTheme.body(fontSize: 13, lang: lang),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(isArabic ? 'حسناً' : 'Great'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsetsDirectional.only(end: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGoldLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentGoldBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: AppTheme.accentGold),
                          const SizedBox(width: 4),
                          Text(
                            isArabic ? 'برو' : 'PRO',
                            style: AppTheme.body(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentGold,
                              lang: lang,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: ActionChip(
                    onPressed: () => PaywallScreen.show(context, trigger: 'dashboard_appbar'),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.workspace_premium_rounded, size: 14, color: AppTheme.accentGold),
                    label: Text(
                      isArabic ? 'أهل برو' : 'Get Pro',
                      style: AppTheme.body(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGold,
                        lang: lang,
                      ),
                    ),
                    backgroundColor: AppTheme.accentGoldLight,
                    side: const BorderSide(color: AppTheme.accentGoldBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              },
            ),
            // Instant Language Switcher Button
            ActionChip(
              onPressed: _toggleLanguage,
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.language_rounded, size: 14, color: AppTheme.primaryTeal),
              label: Text(
                isArabic ? 'English' : 'العربية',
                style: AppTheme.bodyMedium(fontSize: 11, color: AppTheme.primaryTeal, lang: lang),
              ),
              backgroundColor: AppTheme.primaryTealLight,
              side: const BorderSide(color: AppTheme.primaryTealBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            // Settings Button
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppTheme.inkSecondary, size: 22),
              tooltip: isArabic ? 'الإعدادات والملف' : 'Settings & Profile',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                _reloadHousehold();
              },
            ),
            // Overflow Menu (Export & Diagnostic)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.inkSecondary, size: 22),
              tooltip: isArabic ? 'خيارات إضافية' : 'More Options',
              onSelected: (val) {
                if (val == 'settings') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ).then((_) => _reloadHousehold());
                } else if (val == 'export') {
                  _exportTransactions();
                } else if (val == 'tour') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  ).then((_) => _reloadHousehold());
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, color: AppTheme.primaryTeal, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isArabic ? 'الإعدادات والملف' : 'Settings & Profile',
                        style: AppTheme.body(fontSize: 13, color: AppTheme.inkPrimary, lang: lang),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      const Icon(Icons.file_download_outlined, color: AppTheme.primaryTeal, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isArabic ? 'تصدير البيانات (CSV / إكسل)' : 'Export CSV (Excel)',
                        style: AppTheme.body(fontSize: 13, color: AppTheme.inkPrimary, lang: lang),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'tour',
                  child: Row(
                    children: [
                      const Icon(Icons.assessment_outlined, color: AppTheme.accentGold, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isArabic ? 'التقييم المالي الشامل' : 'Financial Assessment',
                        style: AppTheme.body(fontSize: 13, color: AppTheme.inkPrimary, lang: lang),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: ValueListenableBuilder(
            valueListenable: _db.transactionListenable,
            builder: (context, box, child) {
              final summary = _db.getMonthlySummary(_selectedMonth);
              final transactions = _db.getTransactions(month: _selectedMonth);
              final members = _db.getMembers();
              final memberSpending = _db.getMemberSpendingBreakdown(_selectedMonth);
              final categories = {for (var c in _db.getCategories()) c.id: c};
              final memberMap = {for (var m in members) m.id: m};

              final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
                  _selectedMonth.month == DateTime.now().month;

              return RefreshIndicator(
                onRefresh: () async {
                  _reloadHousehold();
                  setState(() {});
                },
                color: AppTheme.primaryTeal,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Top spacing
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // Month Selector Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildMonthSelector(lang, isCurrentMonth),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 14)),

                    // Hero Card: Net Household Position
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildHeroCard(summary, lang),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 14)),

                    // Contributor Breakdown Bar
                    if (summary.totalExpense > 0 && memberSpending.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildContributorCard(
                            memberSpending,
                            summary.totalExpense,
                            memberMap,
                            lang,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 18)),

                    // Quick-Add Action Button
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          onPressed: _openQuickAdd,
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                          label: Text(
                            isArabic ? 'إضافة عملية جديدة' : 'Add Transaction',
                            style: AppTheme.bodyMedium(fontSize: 16, color: Colors.white, lang: lang),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // Section Heading: Activity Stream
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isArabic ? 'سجل العمليات' : 'Monthly Activity',
                              style: AppTheme.label(fontSize: 13, color: AppTheme.inkSecondary, lang: lang),
                            ),
                            Text(
                              '${transactions.length} ${isArabic ? "عمليات" : "records"}',
                              style: AppTheme.amountMonospace(fontSize: 12, color: AppTheme.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // Transaction Feed
                    if (transactions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(isArabic, lang),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final tx = transactions[index];
                              final cat = categories[tx.categoryId];
                              final member = memberMap[tx.memberId];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildTransactionTile(
                                  tx,
                                  cat,
                                  member,
                                  lang,
                                ),
                              );
                            },
                            childCount: transactions.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildMonthSelector(String lang, bool isCurrentMonth) {
    String monthLabel;
    try {
      final monthFormat = DateFormat('MMMM yyyy', lang == 'ar' ? 'ar' : 'en');
      monthLabel = monthFormat.format(_selectedMonth);
    } catch (_) {
      monthLabel = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.inkPrimary),
            onPressed: () => _changeMonth(-1),
            tooltip: lang == 'ar' ? 'الشهر السابق' : 'Previous Month',
          ),
          GestureDetector(
            onTap: _resetToCurrentMonth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthLabel,
                  style: AppTheme.bodyMedium(fontSize: 15, lang: lang),
                ),
                if (!isCurrentMonth) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGoldLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.accentGoldBorder),
                    ),
                    child: Text(
                      lang == 'ar' ? 'العودة لليوم' : 'Today',
                      style: AppTheme.label(fontSize: 10, color: AppTheme.accentGold, lang: lang),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.inkPrimary),
            onPressed: () => _changeMonth(1),
            tooltip: lang == 'ar' ? 'الشهر القادم' : 'Next Month',
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(MonthlySummary summary, String lang) {
    final isPositive = summary.netPosition >= 0;
    final isArabic = lang == 'ar';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.inkPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtitle tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الصافي المالي للأسرة' : 'Net Household Position',
                style: AppTheme.label(fontSize: 13, color: AppTheme.inkSecondary, lang: lang),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? AppTheme.primaryTealLight : AppTheme.terracottaLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPositive
                      ? (isArabic ? 'وفر إيجابي' : 'Surplus')
                      : (isArabic ? 'عجز شهري' : 'Deficit'),
                  style: AppTheme.label(
                    fontSize: 11,
                    color: isPositive ? AppTheme.primaryTeal : AppTheme.terracotta,
                    lang: lang,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // The One Big Number: Net Position in IBM Plex Mono + Newsreader
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatCurrency(summary.netPosition),
                  style: AppTheme.amountMonospace(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: isPositive ? AppTheme.primaryTeal : AppTheme.terracotta,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppTheme.surfaceBorder),
          const SizedBox(height: 14),

          // Inflow and Outflow Sub-Metrics
          Row(
            children: [
              // Inflow (Income)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward_rounded, size: 14, color: AppTheme.primaryTeal),
                        const SizedBox(width: 4),
                        Text(
                          isArabic ? 'إجمالي الدخل (+)' : 'Total Inflow (+)',
                          style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(summary.totalIncome),
                      style: AppTheme.amountMonospace(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ),

              Container(height: 28, width: 1, color: AppTheme.surfaceBorder),

              // Outflow (Expenses)
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 14, color: AppTheme.terracotta),
                          const SizedBox(width: 4),
                          Text(
                            isArabic ? 'إجمالي المصروف (-)' : 'Total Outflow (-)',
                            style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(summary.totalExpense),
                        style: AppTheme.amountMonospace(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.terracotta,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributorCard(
    Map<String, double> memberSpending,
    double totalExpense,
    Map<String, Member> memberMap,
    String lang,
  ) {
    final isArabic = lang == 'ar';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'توزيع الإنفاق حسب المساهم' : 'Contributor Spending Split',
                style: AppTheme.label(fontSize: 12, color: AppTheme.inkSecondary, lang: lang),
              ),
              const Icon(Icons.pie_chart_outline_rounded, size: 16, color: AppTheme.inkMuted),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: memberSpending.entries.map((e) {
                  final member = memberMap[e.key];
                  final ratio = totalExpense > 0 ? (e.value / totalExpense) : 0.0;
                  final color = _parseColor(member?.colorHex ?? '#0F6E56');

                  return Expanded(
                    flex: (ratio * 1000).toInt().clamp(1, 1000),
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Member labels with percentage
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: memberSpending.entries.map((e) {
              final member = memberMap[e.key];
              final ratio = totalExpense > 0 ? (e.value / totalExpense * 100) : 0.0;
              final color = _parseColor(member?.colorHex ?? '#0F6E56');

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${member?.name ?? "عضو"}: ${ratio.toStringAsFixed(0)}%',
                    style: AppTheme.body(fontSize: 12, color: AppTheme.inkSecondary, lang: lang),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '(${_formatCurrency(e.value)})',
                    style: AppTheme.amountMonospace(fontSize: 11, color: AppTheme.inkMuted),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
    Transaction tx,
    Category? cat,
    Member? member,
    String lang,
  ) {
    final isExpense = tx.isExpense;
    final isArabic = lang == 'ar';
    final memberColor = _parseColor(member?.colorHex ?? '#0F6E56');

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppTheme.terracotta,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              isArabic ? 'حذف العملية' : 'Delete Transaction',
              style: AppTheme.editorialHeading(fontSize: 18, lang: lang),
            ),
            content: Text(
              isArabic
                  ? 'هل أنت متأكد من حذف هذه العملية من سجل الأسرة؟'
                  : 'Are you sure you want to delete this transaction?',
              style: AppTheme.body(lang: lang),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.terracotta),
                child: Text(isArabic ? 'حذف' : 'Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await _db.deleteTransaction(tx.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isArabic ? 'تم حذف العملية' : 'Transaction deleted'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Row(
          children: [
            // Category Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isExpense ? AppTheme.surfaceMuted : AppTheme.primaryTealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(cat?.iconName ?? 'category'),
                size: 20,
                color: isExpense ? AppTheme.inkPrimary : AppTheme.primaryTeal,
              ),
            ),
            const SizedBox(width: 12),

            // Category name + Contributor + Note
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          cat?.localizedName(lang) ?? (isExpense ? 'مصروف' : 'دخل'),
                          style: AppTheme.bodyMedium(fontSize: 14, lang: lang),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Member Chip
                      if (member != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: memberColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: memberColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            member.name,
                            style: AppTheme.label(fontSize: 10, color: memberColor, lang: lang),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        () {
                          try {
                            return DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en').format(tx.date);
                          } catch (_) {
                            return '${tx.date.day}/${tx.date.month}';
                          }
                        }(),
                        style: AppTheme.body(fontSize: 12, color: AppTheme.inkMuted, lang: lang),
                      ),
                      if (tx.note != null && tx.note!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('•', style: AppTheme.body(fontSize: 12, color: AppTheme.inkMuted, lang: lang)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tx.note!,
                            style: AppTheme.body(fontSize: 12, color: AppTheme.inkSecondary, lang: lang),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Monospaced Amount
            Text(
              '${isExpense ? "-" : "+"} ${_formatCurrency(tx.amount)}',
              style: AppTheme.amountMonospace(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isExpense ? AppTheme.terracotta : AppTheme.primaryTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isArabic, String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: AppTheme.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'لا توجد عمليات مسجلة لهذا الشهر' : 'No transactions this month',
              style: AppTheme.editorialHeading(fontSize: 18, lang: lang),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'سجل مصاريف ودخل الأسرة بكل سهولة لمتابعة الصافي والزكاة'
                  : 'Log joint expenses and income to track net household position',
              style: AppTheme.body(fontSize: 13, color: AppTheme.inkMuted, lang: lang),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
