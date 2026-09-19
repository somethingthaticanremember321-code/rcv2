import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/category_budget_override.dart';
import '../models/household.dart';
import '../services/database_service.dart';
import '../services/paywall_service.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

class CategoryBudgetsScreen extends StatefulWidget {
  final DateTime? initialMonth;

  const CategoryBudgetsScreen({
    super.key,
    this.initialMonth,
  });

  @override
  State<CategoryBudgetsScreen> createState() => _CategoryBudgetsScreenState();
}

class _CategoryBudgetsScreenState extends State<CategoryBudgetsScreen> {
  final DatabaseService _db = DatabaseService();
  late DateTime _selectedMonth;
  late Household _household;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _household = _db.getHousehold();
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

  String _formatCurrency(double amount) {
    return AppTheme.formatMoney(
      amount,
      currencyCode: _household.currencyCode,
      currencySymbol: _household.currencySymbol,
      lang: _household.preferredLanguage,
    );
  }

  void _openBudgetEditSheet(CategoryBudgetStatus status) async {
    final yearMonth = DateFormat('yyyy-MM').format(_selectedMonth);
    final existingOverride = _db.getCategoryBudgetOverride(status.category.id, yearMonth);

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: CategoryBudgetEditSheet(
          category: status.category,
          currentStatus: status,
          currentOverride: existingOverride,
          selectedMonth: _selectedMonth,
          household: _household,
        ),
      ),
    );

    if (updated == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _household = _db.getHousehold();
    final isArabic = _household.preferredLanguage == 'ar';
    final lang = _household.preferredLanguage;
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final yearMonth = DateFormat('yyyy-MM').format(_selectedMonth);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.creamBg,
        appBar: AppBar(
          backgroundColor: AppTheme.creamBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            isArabic ? 'ميزانية النفقات' : 'Category Budgets',
            style: AppTheme.brandTitle(lang: lang),
          ),
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _db.transactionListenable,
              _db.categoryListenable,
              _db.overrideListenable,
            ]),
            builder: (context, _) {
              final statuses = _db.getCategoryBudgetStatuses(_selectedMonth);
              final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
                  _selectedMonth.month == DateTime.now().month;

              double totalBudget = 0.0;
              double totalSpent = 0.0;
              int overrideCount = 0;

              for (final s in statuses) {
                totalBudget += s.effectiveBudget;
                totalSpent += s.actualSpent;
                if (s.hasOverride) overrideCount++;
              }

              final remainingBuffer = totalBudget - totalSpent;
              final overallProgress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 6)),

                  // Month Selector
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMonthSelector(lang, isCurrentMonth),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // Overall Budget Gauge Hero Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildOverallBudgetHero(
                        totalBudget,
                        totalSpent,
                        remainingBuffer,
                        overallProgress,
                        overrideCount,
                        lang,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // Seasonal Override Announcement Banner (if any overrides exist for this month)
                  if (overrideCount > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSeasonalOverrideBanner(overrideCount, yearMonth, lang),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // Section Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isArabic ? 'تصنيفات النفقات' : 'Expense Categories',
                            style: AppTheme.label(fontSize: 13, color: AppTheme.inkSecondary, lang: lang),
                          ),
                          Text(
                            isArabic ? 'انقر لتعديل الميزانية' : 'Tap category to adjust',
                            style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // Category Cards List
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final status = statuses[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildCategoryCard(status, lang),
                          );
                        },
                        childCount: statuses.length,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

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
          ),
        ],
      ),
    );
  }

  Widget _buildOverallBudgetHero(
    double totalBudget,
    double totalSpent,
    double remainingBuffer,
    double overallProgress,
    int overrideCount,
    String lang,
  ) {
    final isArabic = lang == 'ar';
    final isOverBudget = remainingBuffer < 0;
    final percent = (overallProgress * 100).toInt();

    Color statusColor;
    if (isOverBudget) {
      statusColor = AppTheme.terracotta;
    } else if (overallProgress > 0.85) {
      statusColor = AppTheme.accentGold;
    } else {
      statusColor = AppTheme.primaryTeal;
    }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'إجمالي ميزانية الأسرة' : 'Total Household Allocation',
                style: AppTheme.label(fontSize: 13, color: AppTheme.inkSecondary, lang: lang),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverBudget
                      ? AppTheme.terracottaLight
                      : (overallProgress > 0.85 ? AppTheme.accentGoldLight : AppTheme.primaryTealLight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$percent% ${isArabic ? "مستهلك" : "utilized"}',
                  style: AppTheme.label(fontSize: 11, color: statusColor, lang: lang),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Remaining / Deficit Number
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatCurrency(remainingBuffer.abs()),
                  style: AppTheme.amountMonospace(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOverBudget
                      ? (isArabic ? 'عجز تجاوز الميزانية' : 'over budget')
                      : (isArabic ? 'متبقي من الميزانية' : 'available buffer'),
                  style: AppTheme.body(fontSize: 13, color: AppTheme.inkMuted, lang: lang),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 10,
              backgroundColor: AppTheme.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.surfaceBorder),
          const SizedBox(height: 14),

          // Sub metrics: Total Budget vs Total Spent
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'المصروف الفعلي' : 'Actual Outflow',
                    style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(totalSpent),
                    style: AppTheme.amountMonospace(fontSize: 14, color: AppTheme.inkPrimary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isArabic ? 'الميزانية المحددة' : 'Budget Target',
                    style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(totalBudget),
                    style: AppTheme.amountMonospace(fontSize: 14, color: AppTheme.inkPrimary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonalOverrideBanner(int count, String yearMonth, String lang) {
    final isArabic = lang == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentGoldLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentGoldBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabic
                  ? 'يوجد $count تعديلات موسمية استثنائية نشطة لهذا الشهر (رمضان / الأعياد)'
                  : '$count seasonal budget adjustments active for $yearMonth',
              style: AppTheme.body(fontSize: 12, color: AppTheme.inkPrimary, lang: lang),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryBudgetStatus status, String lang) {
    final isArabic = lang == 'ar';
    final isOver = status.isOverBudget;
    final progress = status.progress;

    Color barColor;
    if (isOver) {
      barColor = AppTheme.terracotta;
    } else if (progress > 0.85) {
      barColor = AppTheme.accentGold;
    } else {
      barColor = AppTheme.primaryTeal;
    }

    return GestureDetector(
      onTap: () => _openBudgetEditSheet(status),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOver ? AppTheme.terracottaBorder : AppTheme.surfaceBorder,
            width: isOver ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Icon, Title, Override Badge, Edit Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOver ? AppTheme.terracottaLight : AppTheme.primaryTealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(status.category.iconName),
                    size: 18,
                    color: isOver ? AppTheme.terracotta : AppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.category.localizedName(lang),
                        style: AppTheme.bodyMedium(fontSize: 14, lang: lang),
                      ),
                      if (status.hasOverride)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGoldLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.accentGoldBorder),
                                ),
                                child: Text(
                                  isArabic ? '🌙 تعديل موسمي نشط' : '🌙 Seasonal Override',
                                  style: AppTheme.label(fontSize: 9, color: AppTheme.accentGold, lang: lang),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined, size: 16, color: AppTheme.inkMuted),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppTheme.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 10),

            // Spent vs Budget & Remaining Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _formatCurrency(status.actualSpent),
                      style: AppTheme.amountMonospace(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: barColor,
                      ),
                    ),
                    Text(
                      ' / ${_formatCurrency(status.effectiveBudget)}',
                      style: AppTheme.amountMonospace(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  isOver
                      ? '${isArabic ? "تجاوز بـ" : "over"} ${_formatCurrency(status.actualSpent - status.effectiveBudget)}'
                      : '${isArabic ? "متبقي" : "left"} ${_formatCurrency(status.remainingBudget)}',
                  style: AppTheme.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOver ? AppTheme.terracotta : AppTheme.inkSecondary,
                    lang: lang,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet to Edit Baseline Budget & Seasonal Overrides
class CategoryBudgetEditSheet extends StatefulWidget {
  final Category category;
  final CategoryBudgetStatus currentStatus;
  final CategoryBudgetOverride? currentOverride;
  final DateTime selectedMonth;
  final Household household;

  const CategoryBudgetEditSheet({
    super.key,
    required this.category,
    required this.currentStatus,
    this.currentOverride,
    required this.selectedMonth,
    required this.household,
  });

  @override
  State<CategoryBudgetEditSheet> createState() => _CategoryBudgetEditSheetState();
}

class _CategoryBudgetEditSheetState extends State<CategoryBudgetEditSheet> {
  final DatabaseService _db = DatabaseService();
  final PaywallService _paywallService = PaywallService();
  late TextEditingController _baselineController;
  late TextEditingController _overrideController;
  late TextEditingController _noteController;

  bool _isOverrideActive = false;
  String _selectedSeasonTag = 'ramadan';

  final List<Map<String, String>> _seasonalPresets = [
    {'id': 'ramadan', 'labelAr': '🌙 ولائم ومؤن رمضان', 'labelEn': '🌙 Ramadan Hospitality'},
    {'id': 'eid', 'labelAr': '🎉 عيدية وتجهيزات العيد', 'labelEn': '🎉 Eid Hospitality & Gifts'},
    {'id': 'summer_break', 'labelAr': '☀️ سفر وإجازة الصيف', 'labelEn': '☀️ Summer Holidays'},
    {'id': 'custom', 'labelAr': '✏️ تعديل استثنائي خاص', 'labelEn': '✏️ Custom Adjustment'},
  ];

  @override
  void initState() {
    super.initState();
    _baselineController = TextEditingController(
      text: widget.category.baselineMonthlyBudget > 0
          ? widget.category.baselineMonthlyBudget.toStringAsFixed(0)
          : '',
    );

    _isOverrideActive = widget.currentOverride != null;
    _overrideController = TextEditingController(
      text: widget.currentOverride != null
          ? widget.currentOverride!.overrideBudget.toStringAsFixed(0)
          : (widget.category.baselineMonthlyBudget * 1.3).toStringAsFixed(0),
    );
    _noteController = TextEditingController(text: widget.currentOverride?.note ?? '');
  }

  @override
  void dispose() {
    _baselineController.dispose();
    _overrideController.dispose();
    _noteController.dispose();
    super.dispose();
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

  void _saveBudget() async {
    final rawBaseline = _baselineController.text.trim().replaceAll(',', '');
    final baseline = double.tryParse(rawBaseline) ?? widget.category.baselineMonthlyBudget;
    final yearMonth = DateFormat('yyyy-MM').format(widget.selectedMonth);

    // 1. If enabling a seasonal override, verify entitlement first
    if (_isOverrideActive && widget.currentOverride == null) {
      final existingOverrides = _db.getCategoryBudgetOverrides(yearMonth);
      if (!_paywallService.canAddSeasonalOverride(existingOverrides.length)) {
        final upgraded = await PaywallScreen.show(context, trigger: 'multi_seasonal_override');
        if (upgraded != true && !_paywallService.canAddSeasonalOverride(existingOverrides.length)) {
          return;
        }
      }
    }

    if (!mounted) return;

    // 2. Update baseline budget on category
    final updatedCategory = widget.category.copyWith(baselineMonthlyBudget: baseline);
    await _db.updateCategory(updatedCategory);

    // 3. Handle Seasonal Override
    if (_isOverrideActive) {
      final rawOverride = _overrideController.text.trim().replaceAll(',', '');
      final overrideAmount = double.tryParse(rawOverride) ?? baseline;

      final override = CategoryBudgetOverride(
        id: widget.currentOverride?.id ?? const Uuid().v4(),
        householdId: widget.household.id,
        categoryId: widget.category.id,
        yearMonth: yearMonth,
        overrideBudget: overrideAmount,
        note: _noteController.text.trim().isEmpty
            ? _selectedSeasonTag
            : '$_selectedSeasonTag: ${_noteController.text.trim()}',
      );
      await _db.setCategoryBudgetOverride(override);
    } else {
      // If disabled, remove existing override
      await _db.removeCategoryBudgetOverride(widget.category.id, yearMonth);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.household.preferredLanguage == 'ar';
    final lang = widget.household.preferredLanguage;
    String monthLabel;
    try {
      monthLabel = DateFormat('MMMM yyyy', isArabic ? 'ar' : 'en').format(widget.selectedMonth);
    } catch (_) {
      monthLabel = '${widget.selectedMonth.year}-${widget.selectedMonth.month.toString().padLeft(2, '0')}';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
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

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(widget.category.iconName),
                    color: AppTheme.primaryTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? widget.category.nameAr : widget.category.nameEn,
                        style: AppTheme.brandTitle(lang: lang).copyWith(fontSize: 18),
                      ),
                      Text(
                        isArabic ? 'تعديل ميزانية التصنيف' : 'Edit Category Budget',
                        style: AppTheme.body(fontSize: 12, color: AppTheme.inkSecondary, lang: lang),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Baseline Budget Input
            Text(
              isArabic ? 'الميزانية الشهرية الأساسية:' : 'Baseline Monthly Budget:',
              style: AppTheme.label(fontSize: 11, color: AppTheme.inkSecondary, lang: lang),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.creamBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Row(
                children: [
                  Text(
                    isArabic ? widget.household.currencySymbol : widget.household.currencyCode,
                    style: AppTheme.body(fontSize: 14, color: AppTheme.inkSecondary, lang: lang),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _baselineController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTheme.amountMonospace(fontSize: 20, color: AppTheme.inkPrimary),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: AppTheme.amountMonospace(fontSize: 20, color: AppTheme.inkMuted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // GCC Seasonal Override Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isOverrideActive ? AppTheme.accentGoldLight : AppTheme.creamBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isOverrideActive ? AppTheme.accentGoldBorder : AppTheme.surfaceBorder,
                  width: _isOverrideActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'تعديل استثنائي لموسم محدد' : 'Seasonal Month Override',
                              style: AppTheme.bodyMedium(
                                fontSize: 14,
                                color: _isOverrideActive ? AppTheme.accentGold : AppTheme.inkPrimary,
                                lang: lang,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArabic
                                  ? 'لشهر $monthLabel فقط دون تغيير الميزانية السنوية'
                                  : 'Applies only to $monthLabel without changing baseline',
                              style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isOverrideActive,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.accentGold,
                        onChanged: (val) async {
                          if (val && widget.currentOverride == null) {
                            final yearMonth = DateFormat('yyyy-MM').format(widget.selectedMonth);
                            final existingOverrides = _db.getCategoryBudgetOverrides(yearMonth);
                            if (!_paywallService.canAddSeasonalOverride(existingOverrides.length)) {
                              final upgraded = await PaywallScreen.show(context, trigger: 'multi_seasonal_override');
                              if (upgraded != true && !_paywallService.canAddSeasonalOverride(existingOverrides.length)) {
                                return;
                              }
                            }
                          }
                          if (!mounted) return;
                          setState(() => _isOverrideActive = val);
                        },
                      ),
                    ],
                  ),

                  if (_isOverrideActive) ...[
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'المناسبة / الموسم:' : 'Seasonal Reason Preset:',
                      style: AppTheme.label(fontSize: 11, color: AppTheme.inkSecondary, lang: lang),
                    ),
                    const SizedBox(height: 8),

                    // Season chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _seasonalPresets.map((season) {
                        final isSelected = _selectedSeasonTag == season['id'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedSeasonTag = season['id']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.accentGold : AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppTheme.accentGold : AppTheme.accentGoldBorder,
                              ),
                            ),
                            child: Text(
                              isArabic ? season['labelAr']! : season['labelEn']!,
                              style: AppTheme.body(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? Colors.white : AppTheme.inkPrimary,
                                lang: lang,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Override Amount Field
                    Text(
                      isArabic ? 'الميزانية المعدلة لشهر $monthLabel' : 'Override Budget for $monthLabel',
                      style: AppTheme.label(fontSize: 11, color: AppTheme.inkSecondary, lang: lang),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentGoldBorder),
                      ),
                      child: Row(
                        children: [
                          Text(
                            isArabic ? widget.household.currencySymbol : widget.household.currencyCode,
                            style: AppTheme.amountMonospace(fontSize: 16, color: AppTheme.accentGold),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _overrideController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: AppTheme.amountMonospace(
                                fontSize: 20,
                                color: AppTheme.inkPrimary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _saveBudget,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isArabic ? 'حفظ إعدادات الميزانية' : 'Save Budget Settings',
                style: AppTheme.bodyMedium(fontSize: 16, color: Colors.white, lang: lang),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
