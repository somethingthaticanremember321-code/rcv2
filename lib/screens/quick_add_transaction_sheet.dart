import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/household.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class QuickAddTransactionSheet extends StatefulWidget {
  final Household household;
  final VoidCallback? onTransactionAdded;

  const QuickAddTransactionSheet({
    super.key,
    required this.household,
    this.onTransactionAdded,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Household household,
    VoidCallback? onTransactionAdded,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: QuickAddTransactionSheet(
          household: household,
          onTransactionAdded: onTransactionAdded,
        ),
      ),
    );
  }

  @override
  State<QuickAddTransactionSheet> createState() => _QuickAddTransactionSheetState();
}

class _QuickAddTransactionSheetState extends State<QuickAddTransactionSheet> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedType = 'expense'; // 'expense' or 'income'
  String? _selectedMemberId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  List<Member> _members = [];
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _loadData() {
    _members = _db.getMembers();
    _categories = _db.getCategories();

    // Default member to primary (usually 'self')
    final primaryMember = _members.firstWhere(
      (m) => m.isPrimary,
      orElse: () => _members.isNotEmpty ? _members.first : Member(
        id: 'default',
        householdId: widget.household.id,
        name: 'أنا',
        createdAt: DateTime.now(),
      ),
    );
    _selectedMemberId = primaryMember.id;

    // Default category to Groceries or first available
    if (_categories.isNotEmpty) {
      _selectedCategoryId = _categories.first.id;
    }

    setState(() {
      _isLoading = false;
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

  void _saveTransaction() async {
    final rawAmount = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(rawAmount);

    final isArabic = widget.household.preferredLanguage == 'ar';

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'يرجى إدخال مبلغ صحيح' : 'Please enter a valid amount',
            style: AppTheme.body(color: Colors.white, lang: widget.household.preferredLanguage),
          ),
          backgroundColor: AppTheme.terracotta,
        ),
      );
      return;
    }

    if (_selectedMemberId == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'يرجى اختيار العضو والتصنيف' : 'Please select contributor and category',
            style: AppTheme.body(color: Colors.white, lang: widget.household.preferredLanguage),
          ),
          backgroundColor: AppTheme.terracotta,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final newTx = Transaction(
      id: const Uuid().v4(),
      householdId: widget.household.id,
      memberId: _selectedMemberId!,
      categoryId: _selectedCategoryId!,
      amount: amount,
      type: _selectedType,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _db.addTransaction(newTx);
    widget.onTransactionAdded?.call();

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryTeal,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceCard,
              onSurface: AppTheme.inkPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.household.preferredLanguage == 'ar';
    final lang = widget.household.preferredLanguage;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: _isLoading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
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
                  const SizedBox(height: 14),

                  // Header with Title and Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'إضافة عملية جديدة' : 'New Transaction',
                        style: AppTheme.editorialHeading(fontSize: 20, lang: lang),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: AppTheme.inkMuted, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Expense / Income Segmented Switch
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.creamBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedType = 'expense'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedType == 'expense' ? AppTheme.terracotta : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isArabic ? 'مصروف (-)' : 'Expense (-)',
                                style: AppTheme.bodyMedium(
                                  fontSize: 14,
                                  color: _selectedType == 'expense' ? Colors.white : AppTheme.inkSecondary,
                                  lang: lang,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedType = 'income'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedType == 'income' ? AppTheme.primaryTeal : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isArabic ? 'دخل (+)' : 'Income (+)',
                                style: AppTheme.bodyMedium(
                                  fontSize: 14,
                                  color: _selectedType == 'income' ? Colors.white : AppTheme.inkSecondary,
                                  lang: lang,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Large Amount Input with Currency Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.creamBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedType == 'expense'
                            ? AppTheme.terracottaBorder
                            : AppTheme.primaryTealBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          isArabic ? widget.household.currencySymbol : widget.household.currencyCode,
                          style: AppTheme.amountMonospace(
                            fontSize: 22,
                            color: _selectedType == 'expense' ? AppTheme.terracotta : AppTheme.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            style: AppTheme.amountMonospace(
                              fontSize: 32,
                              color: AppTheme.inkPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: AppTheme.amountMonospace(
                                fontSize: 32,
                                color: AppTheme.inkMuted.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Household Contributor Selector
                  Text(
                    isArabic ? 'من قام بالصرف / الاستلام؟' : 'Contributor Attribution',
                    style: AppTheme.label(fontSize: 12, lang: lang),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _members.map((member) {
                      final isSelected = _selectedMemberId == member.id;
                      final memberColor = _parseColor(member.colorHex);

                      return GestureDetector(
                        onTap: () => setState(() => _selectedMemberId = member.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? memberColor.withValues(alpha: 0.12) : AppTheme.creamBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? memberColor : AppTheme.surfaceBorder,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: memberColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                member.name,
                                style: AppTheme.bodyMedium(
                                  fontSize: 13,
                                  color: isSelected ? AppTheme.inkPrimary : AppTheme.inkSecondary,
                                  lang: lang,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Category Picker
                  Text(
                    isArabic ? 'التصنيف' : 'Category',
                    style: AppTheme.label(fontSize: 12, lang: lang),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategoryId = cat.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryTealLight : AppTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(cat.iconName),
                                size: 16,
                                color: isSelected ? AppTheme.primaryTeal : AppTheme.inkSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.localizedName(lang),
                                style: AppTheme.body(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? AppTheme.primaryTealDark : AppTheme.inkPrimary,
                                  lang: lang,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Date & Note Row
                  Row(
                    children: [
                      // Date Selector
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.creamBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.inkMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    DateFormat('d MMM yyyy').format(_selectedDate),
                                    style: AppTheme.body(fontSize: 13, lang: lang),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Optional Note Field
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.creamBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.surfaceBorder),
                          ),
                          child: TextField(
                            controller: _noteController,
                            style: AppTheme.body(fontSize: 13, lang: lang),
                            decoration: InputDecoration(
                              hintText: isArabic ? 'ملاحظة (اختياري)' : 'Note (optional)',
                              hintStyle: AppTheme.body(fontSize: 13, color: AppTheme.inkMuted, lang: lang),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton(
                    onPressed: _saveTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedType == 'expense' ? AppTheme.primaryTeal : AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isArabic ? 'حفظ العملية' : 'Save Transaction',
                      style: AppTheme.bodyMedium(
                        fontSize: 16,
                        color: Colors.white,
                        lang: lang,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
