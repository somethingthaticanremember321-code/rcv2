import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/household.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/paywall_service.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

class HouseholdSplitScreen extends StatefulWidget {
  final DateTime? initialMonth;

  const HouseholdSplitScreen({
    super.key,
    this.initialMonth,
  });

  @override
  State<HouseholdSplitScreen> createState() => _HouseholdSplitScreenState();
}

class _HouseholdSplitScreenState extends State<HouseholdSplitScreen> {
  final DatabaseService _db = DatabaseService();
  final PaywallService _paywallService = PaywallService();
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

  String _getRoleLabel(String role, bool isArabic) {
    switch (role) {
      case 'self':
        return isArabic ? 'أنا (الأساسي)' : 'Self (Primary)';
      case 'spouse':
        return isArabic ? 'الزوج / الزوجة' : 'Spouse / Partner';
      case 'contributor':
        return isArabic ? 'مساهم' : 'Contributor';
      case 'dependent':
        return isArabic ? 'تابع' : 'Dependent';
      default:
        return role;
    }
  }

  void _openMemberSheet([Member? existingMember]) async {
    // If adding a new member and not Pro, check entitlement limit
    if (existingMember == null) {
      final currentMembers = _db.getMembers();
      if (!_paywallService.canAddMember(currentMembers.length)) {
        final upgraded = await PaywallScreen.show(context, trigger: 'unlimited_members');
        if (upgraded != true && !_paywallService.canAddMember(currentMembers.length)) {
          return;
        }
      }
    }

    if (!mounted) return;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: MemberEditSheet(
          household: _household,
          existingMember: existingMember,
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

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.creamBg,
        appBar: AppBar(
          backgroundColor: AppTheme.creamBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            isArabic ? 'توزيع نفقات الأسرة' : 'Household Split',
            style: AppTheme.brandTitle(lang: lang),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_outlined, color: AppTheme.primaryTeal),
              tooltip: isArabic ? 'إضافة فرد' : 'Add Member',
              onPressed: () => _openMemberSheet(),
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _db.transactionListenable,
              _db.memberListenable,
            ]),
            builder: (context, _) {
              final members = _db.getMembers();
              final transactions = _db.getTransactions(month: _selectedMonth, type: 'expense');
              final memberSpending = _db.getMemberSpendingBreakdown(_selectedMonth);
              final categories = {for (var c in _db.getCategories()) c.id: c};

              double totalHouseholdExpense = 0.0;
              for (final t in transactions) {
                totalHouseholdExpense += t.amount;
              }

              final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
                  _selectedMonth.month == DateTime.now().month;

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

                  // Split Ratio Hero Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSplitRatioHero(
                        totalHouseholdExpense,
                        memberSpending,
                        members,
                        lang,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isArabic ? 'أفراد الأسرة والمساهمات' : 'Contributors & Details',
                            style: AppTheme.label(fontSize: 13, color: AppTheme.inkSecondary, lang: lang),
                          ),
                          Text(
                            '${members.length} ${isArabic ? "أفراد" : "members"}',
                            style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // Member Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final member = members[index];
                          final spent = memberSpending[member.id] ?? 0.0;
                          final memberTxs = transactions.where((t) => t.memberId == member.id).toList();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildMemberCard(
                              member,
                              spent,
                              totalHouseholdExpense,
                              memberTxs,
                              categories,
                              lang,
                            ),
                          );
                        },
                        childCount: members.length,
                      ),
                    ),
                  ),

                  // Add Contributor Quick Button at bottom
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _openMemberSheet(),
                        icon: const Icon(Icons.add, color: AppTheme.primaryTeal, size: 18),
                        label: Text(
                          isArabic ? 'إضافة مساهم جديد للأسرة' : 'Add New Contributor',
                          style: AppTheme.bodyMedium(fontSize: 14, color: AppTheme.primaryTeal, lang: lang),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppTheme.primaryTealBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: AppTheme.surfaceCard,
                        ),
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

  Widget _buildSplitRatioHero(
    double totalHouseholdExpense,
    Map<String, double> memberSpending,
    List<Member> members,
    String lang,
  ) {
    final isArabic = lang == 'ar';
    final memberMap = {for (var m in members) m.id: m};

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
                isArabic ? 'نسبة مساهمة النفقات هذا الشهر' : 'Monthly Expense Split Ratio',
                style: AppTheme.label(fontSize: 13, color: AppTheme.inkSecondary, lang: lang),
              ),
              Text(
                _formatCurrency(totalHouseholdExpense),
                style: AppTheme.amountMonospace(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.terracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Multi-color segmented split bar
          if (totalHouseholdExpense > 0 && memberSpending.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: memberSpending.entries.map((e) {
                    final member = memberMap[e.key];
                    final ratio = (e.value / totalHouseholdExpense).clamp(0.01, 1.0);
                    final color = _parseColor(member?.colorHex ?? '#0F6E56');

                    return Expanded(
                      flex: (ratio * 1000).toInt(),
                      child: Container(color: color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Chips with percentages
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: memberSpending.entries.map((e) {
                final member = memberMap[e.key];
                final percent = (e.value / totalHouseholdExpense * 100).toInt();
                final color = _parseColor(member?.colorHex ?? '#0F6E56');

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${member?.name ?? "عضو"}: $percent%',
                      style: AppTheme.bodyMedium(fontSize: 13, color: AppTheme.inkPrimary, lang: lang),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${_formatCurrency(e.value)})',
                      style: AppTheme.amountMonospace(fontSize: 11, color: AppTheme.inkMuted),
                    ),
                  ],
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: Text(
                isArabic ? 'لم تسجل نفقات لهذا الشهر بعد' : 'No expenses recorded for this month',
                style: AppTheme.body(fontSize: 13, color: AppTheme.inkMuted, lang: lang),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    Member member,
    double spent,
    double totalHouseholdExpense,
    List<Transaction> memberTxs,
    Map<String, Category> categories,
    String lang,
  ) {
    final isArabic = lang == 'ar';
    final memberColor = _parseColor(member.colorHex);
    final percentage = totalHouseholdExpense > 0 ? (spent / totalHouseholdExpense * 100).toInt() : 0;

    // Group expenses by category
    final categoryTotals = <String, double>{};
    for (final tx in memberTxs) {
      categoryTotals[tx.categoryId] = (categoryTotals[tx.categoryId] ?? 0.0) + tx.amount;
    }

    // Top categories sorted by spend
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Avatar, Name, Role Tag, Edit Button
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: memberColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: memberColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  member.name.isNotEmpty ? member.name[0] : '?',
                  style: AppTheme.bodyMedium(
                    fontSize: 16,
                    color: memberColor,
                    lang: lang,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name,
                          style: AppTheme.bodyMedium(fontSize: 15, lang: lang),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getRoleLabel(member.role, isArabic),
                            style: AppTheme.label(fontSize: 10, color: AppTheme.inkSecondary, lang: lang),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${memberTxs.length} ${isArabic ? "عمليات مسجلة" : "transactions logged"}',
                      style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openMemberSheet(member),
                icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.inkMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Contributed Amount & Share
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'إجمالي ما صُرف' : 'Total Spent',
                style: AppTheme.label(fontSize: 12, color: AppTheme.inkMuted, lang: lang),
              ),
              Row(
                children: [
                  Text(
                    _formatCurrency(spent),
                    style: AppTheme.amountMonospace(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkPrimary,
                    ),
                  ),
                  if (totalHouseholdExpense > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: memberColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$percentage%',
                        style: AppTheme.amountMonospace(fontSize: 11, color: memberColor),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Top categories breakdown (if any)
          if (sortedCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.surfaceBorder),
            const SizedBox(height: 10),
            Text(
              isArabic ? 'أبرز النفقات:' : 'Top Outflows:',
              style: AppTheme.label(fontSize: 10, color: AppTheme.inkMuted, lang: lang),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: sortedCategories.take(3).map((e) {
                final cat = categories[e.key];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.creamBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat?.localizedName(lang) ?? (isArabic ? 'تصنيف' : 'Category'),
                        style: AppTheme.body(fontSize: 11, color: AppTheme.inkPrimary, lang: lang),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatCurrency(e.value),
                        style: AppTheme.amountMonospace(fontSize: 10, color: AppTheme.inkMuted),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet to Add or Edit Household Member
class MemberEditSheet extends StatefulWidget {
  final Household household;
  final Member? existingMember;

  const MemberEditSheet({
    super.key,
    required this.household,
    this.existingMember,
  });

  @override
  State<MemberEditSheet> createState() => _MemberEditSheetState();
}

class _MemberEditSheetState extends State<MemberEditSheet> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late String _selectedRole;
  late String _selectedColorHex;

  final List<String> _colorPalette = [
    '#0F6E56', // Deep Teal
    '#C9962C', // Antique Gold
    '#1E3A8A', // Deep Navy
    '#D97706', // Warm Ochre
    '#B5453A', // Terracotta
    '#059669', // Emerald
    '#7C3AED', // Royal Plum
    '#0284C7', // Arabian Gulf Blue
  ];

  final List<Map<String, String>> _roles = [
    {'id': 'self', 'labelAr': 'أنا (الأساسي)', 'labelEn': 'Self (Primary)'},
    {'id': 'spouse', 'labelAr': 'الزوج / الزوجة', 'labelEn': 'Spouse / Partner'},
    {'id': 'contributor', 'labelAr': 'مساهم مستقل', 'labelEn': 'Contributor'},
    {'id': 'dependent', 'labelAr': 'تابع / نفقة', 'labelEn': 'Dependent'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingMember?.name ?? '');
    _selectedRole = widget.existingMember?.role ?? 'contributor';
    _selectedColorHex = widget.existingMember?.colorHex ?? _colorPalette[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryTeal;
    }
  }

  void _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    final isNew = widget.existingMember == null;
    final now = DateTime.now();

    if (isNew) {
      final newMember = Member(
        id: const Uuid().v4(),
        householdId: widget.household.id,
        name: _nameController.text.trim(),
        role: _selectedRole,
        colorHex: _selectedColorHex,
        isPrimary: _selectedRole == 'self',
        createdAt: now,
      );
      await _db.addMember(newMember);
    } else {
      final updated = widget.existingMember!.copyWith(
        name: _nameController.text.trim(),
        role: _selectedRole,
        colorHex: _selectedColorHex,
      );
      await _db.updateMember(updated);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _deleteMember() async {
    if (widget.existingMember == null) return;

    final isArabic = widget.household.preferredLanguage == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف المساهم' : 'Remove Contributor'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من حذف ${widget.existingMember!.name} من قائمة أفراد الأسرة؟'
              : 'Are you sure you want to remove ${widget.existingMember!.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.terracotta),
            child: Text(isArabic ? 'حذف' : 'Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteMember(widget.existingMember!.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.household.preferredLanguage == 'ar';
    final lang = widget.household.preferredLanguage;
    final isNew = widget.existingMember == null;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _formKey,
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

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNew
                        ? (isArabic ? 'إضافة مساهم جديد' : 'Add Contributor')
                        : (isArabic ? 'تعديل بيانات المساهم' : 'Edit Contributor'),
                    style: AppTheme.editorialHeading(fontSize: 19, lang: lang),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.inkMuted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Member Name
              Text(
                isArabic ? 'اسم المساهم *' : 'Contributor Name *',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return isArabic ? 'يرجى إدخال الاسم' : 'Please enter name';
                  }
                  return null;
                },
                style: AppTheme.body(fontSize: 15, color: AppTheme.inkPrimary, lang: lang),
                decoration: InputDecoration(
                  hintText: isArabic ? 'مثال: عبد العزيز / نورة' : 'e.g. Nasser / Maryam',
                  filled: true,
                  fillColor: AppTheme.creamBg,
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

              // Role Selector
              Text(
                isArabic ? 'الدور في الأسرة' : 'Household Role',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roles.map((r) {
                  final isSelected = _selectedRole == r['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRole = r['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryTealLight : AppTheme.creamBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        isArabic ? r['labelAr']! : r['labelEn']!,
                        style: AppTheme.body(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryTealDark : AppTheme.inkPrimary,
                          lang: lang,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Color Tag Palette
              Text(
                isArabic ? 'الرمز اللوني للمساهم' : 'Contributor Color Tag',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colorPalette.map((hex) {
                  final isSelected = _selectedColorHex == hex;
                  final color = _parseColor(hex);

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              ElevatedButton(
                onPressed: _saveMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isNew ? (isArabic ? 'إضافة المساهم' : 'Add Member') : (isArabic ? 'حفظ التعديلات' : 'Save Changes'),
                  style: AppTheme.bodyMedium(fontSize: 16, color: Colors.white, lang: lang),
                ),
              ),

              if (!isNew && !(widget.existingMember?.isPrimary ?? false)) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _deleteMember,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.terracotta),
                  child: Text(
                    isArabic ? 'حذف هذا الفرد' : 'Remove This Member',
                    style: AppTheme.body(fontSize: 13, color: AppTheme.terracotta, lang: lang),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
