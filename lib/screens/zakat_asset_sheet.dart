import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:uuid/uuid.dart';

import '../models/household.dart';
import '../models/member.dart';
import '../models/zakat_asset.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class ZakatAssetSheet extends StatefulWidget {
  final Household household;
  final ZakatAsset? existingAsset;

  const ZakatAssetSheet({
    super.key,
    required this.household,
    this.existingAsset,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Household household,
    ZakatAsset? existingAsset,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ZakatAssetSheet(
          household: household,
          existingAsset: existingAsset,
        ),
      ),
    );
  }

  @override
  State<ZakatAssetSheet> createState() => _ZakatAssetSheetState();
}

class _ZakatAssetSheetState extends State<ZakatAssetSheet> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  late String _selectedType;
  late TextEditingController _nameController;
  late TextEditingController _cashValueController;
  late TextEditingController _weightGramsController;
  late TextEditingController _liabilitiesController;
  late TextEditingController _notesController;

  int _selectedKarat = 21; // GCC standard for gold jewelry
  DateTime _hawlStartDate = DateTime.now().subtract(const Duration(days: 354)); // Defaults to completed hawl
  String? _selectedMemberId;

  List<Member> _members = [];

  final List<Map<String, String>> _assetTypes = [
    {'id': 'cash', 'labelAr': '💵 سيولة نقدية وبنوك', 'labelEn': '💵 Cash & Bank'},
    {'id': 'gold', 'labelAr': '🪙 ذهب ومجوهرات', 'labelEn': '🪙 Gold & Jewelry'},
    {'id': 'silver', 'labelAr': '🥈 فضة ومعادن', 'labelEn': '🥈 Silver'},
    {'id': 'investments', 'labelAr': '📈 أسهم واستثمارات', 'labelEn': '📈 Shares & Funds'},
    {'id': 'trade_goods', 'labelAr': '🏢 عروض تجارة', 'labelEn': '🏢 Trade Goods'},
  ];

  final List<int> _karats = [24, 22, 21, 18];

  @override
  void initState() {
    super.initState();
    _members = _db.getMembers();

    final asset = widget.existingAsset;
    _selectedType = asset?.assetType ?? 'cash';
    _nameController = TextEditingController(text: asset?.name ?? '');
    _cashValueController = TextEditingController(
      text: asset != null ? asset.cashValue.toStringAsFixed(0) : '',
    );
    _weightGramsController = TextEditingController(
      text: asset?.weightGrams != null ? asset!.weightGrams!.toStringAsFixed(1) : '',
    );
    _liabilitiesController = TextEditingController(
      text: asset != null && asset.deductibleLiabilities > 0
          ? asset.deductibleLiabilities.toStringAsFixed(0)
          : '',
    );
    _notesController = TextEditingController(text: asset?.notes ?? '');
    _selectedKarat = asset?.purityKarat ?? 21;
    _hawlStartDate = asset?.hawlStartDate ?? DateTime.now().subtract(const Duration(days: 354));
    _selectedMemberId = asset?.memberId;

    if (widget.existingAsset == null && _nameController.text.isEmpty) {
      _setDefaultName();
    }
  }

  void _setDefaultName() {
    final isArabic = widget.household.preferredLanguage == 'ar';
    switch (_selectedType) {
      case 'cash':
        _nameController.text = isArabic ? 'حساب التوفير / سيولة' : 'Savings Account / Cash';
        break;
      case 'gold':
        _nameController.text = isArabic ? 'ذهب ادخار ومجوهرات' : 'Gold Jewelry / Bullion';
        break;
      case 'silver':
        _nameController.text = isArabic ? 'فضة مدخرة' : 'Silver Bullion';
        break;
      case 'investments':
        _nameController.text = isArabic ? 'محفظة الأسهم' : 'Investment Portfolio';
        break;
      case 'trade_goods':
        _nameController.text = isArabic ? 'بضاعة تجارية معدة للبيع' : 'Trade Goods Inventory';
        break;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cashValueController.dispose();
    _weightGramsController.dispose();
    _liabilitiesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _computeValuation() {
    final goldSpot = widget.household.cachedGoldPricePerGram ?? 320.0;
    final silverSpot = widget.household.cachedSilverPricePerGram ?? 4.0;

    if (_selectedType == 'gold') {
      final grams = double.tryParse(_weightGramsController.text.trim()) ?? 0.0;
      final purityRatio = _selectedKarat / 24.0;
      return grams * purityRatio * goldSpot;
    } else if (_selectedType == 'silver') {
      final grams = double.tryParse(_weightGramsController.text.trim()) ?? 0.0;
      return grams * silverSpot;
    } else {
      return double.tryParse(_cashValueController.text.trim()) ?? 0.0;
    }
  }

  void _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    final valuation = _computeValuation();
    final liabilities = double.tryParse(_liabilitiesController.text.trim()) ?? 0.0;
    final weight = double.tryParse(_weightGramsController.text.trim());

    final now = DateTime.now();
    final isNew = widget.existingAsset == null;

    final asset = ZakatAsset(
      id: widget.existingAsset?.id ?? const Uuid().v4(),
      householdId: widget.household.id,
      memberId: _selectedMemberId,
      assetType: _selectedType,
      name: _nameController.text.trim(),
      cashValue: valuation,
      weightGrams: (_selectedType == 'gold' || _selectedType == 'silver') ? weight : null,
      purityKarat: _selectedType == 'gold' ? _selectedKarat : null,
      hawlStartDate: _hawlStartDate,
      deductibleLiabilities: liabilities,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      updatedAt: now,
    );

    if (isNew) {
      await _db.addZakatAsset(asset);
    } else {
      await _db.updateZakatAsset(asset);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _deleteAsset() async {
    if (widget.existingAsset == null) return;
    await _db.deleteZakatAsset(widget.existingAsset!.id);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _pickHawlDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hawlStartDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _hawlStartDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.household.preferredLanguage == 'ar';
    final lang = widget.household.preferredLanguage;
    final currency = widget.household.currencySymbol;
    final isNew = widget.existingAsset == null;
    final valuation = _computeValuation();
    final liabilities = double.tryParse(_liabilitiesController.text.trim()) ?? 0.0;
    final netZakatable = (valuation - liabilities).clamp(0.0, double.infinity);
    final daysElapsed = DateTime.now().difference(_hawlStartDate).inDays;
    final isHawlMet = daysElapsed >= 354; // 354 days in a lunar year

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
                        ? (isArabic ? 'إضافة أصل زكوي' : 'Add Zakatable Asset')
                        : (isArabic ? 'تعديل الأصل الزكوي' : 'Edit Zakatable Asset'),
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
              const SizedBox(height: 16),

              // Asset Type Selector
              Text(
                isArabic ? 'نوع الأصل الزكوي' : 'Asset Classification',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _assetTypes.map((t) {
                  final isSelected = _selectedType == t['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedType = t['id']!;
                        _setDefaultName();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentGoldLight : AppTheme.creamBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.accentGold : AppTheme.surfaceBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        isArabic ? t['labelAr']! : t['labelEn']!,
                        style: AppTheme.body(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppTheme.accentGold : AppTheme.inkPrimary,
                          lang: lang,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Asset Name
              Text(
                isArabic ? 'اسم أو مسمى الأصل *' : 'Asset Description *',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                validator: (v) => v == null || v.trim().isEmpty
                    ? (isArabic ? 'مطلوب' : 'Required')
                    : null,
                style: AppTheme.body(fontSize: 14, color: AppTheme.inkPrimary, lang: lang),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.creamBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Gold Purity & Weight Fields
              if (_selectedType == 'gold') ...[
                Text(
                  isArabic ? 'عيار الذهب' : 'Gold Karat Purity',
                  style: AppTheme.label(fontSize: 12, lang: lang),
                ),
                const SizedBox(height: 6),
                Row(
                  children: _karats.map((k) {
                    final isSelected = _selectedKarat == k;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedKarat = k),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.accentGold : AppTheme.creamBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.accentGold : AppTheme.surfaceBorder,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$k K',
                            style: AppTheme.amountMonospace(
                              fontSize: 13,
                              color: isSelected ? Colors.white : AppTheme.inkPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                Text(
                  isArabic ? 'الوزن الإجمالي (غرام)' : 'Weight in Grams',
                  style: AppTheme.label(fontSize: 12, lang: lang),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.creamBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: TextField(
                    controller: _weightGramsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: AppTheme.amountMonospace(fontSize: 18, color: AppTheme.inkPrimary),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      border: InputBorder.none,
                      suffixText: isArabic ? 'غرام' : 'grams',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (_selectedType == 'silver') ...[
                Text(
                  isArabic ? 'وزن الفضة (غرام)' : 'Silver Weight in Grams',
                  style: AppTheme.label(fontSize: 12, lang: lang),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.creamBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: TextField(
                    controller: _weightGramsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: AppTheme.amountMonospace(fontSize: 18, color: AppTheme.inkPrimary),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      border: InputBorder.none,
                      suffixText: isArabic ? 'غرام' : 'grams',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                // Cash or Market Value
                Text(
                  isArabic ? 'القيمة السوقية الإجمالية ($currency) *' : 'Market Cash Value ($currency) *',
                  style: AppTheme.label(fontSize: 12, lang: lang),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.creamBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: TextField(
                    controller: _cashValueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: AppTheme.amountMonospace(fontSize: 20, color: AppTheme.inkPrimary),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      border: InputBorder.none,
                      prefixText: '$currency ',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Deductible Debt / Liabilities
              Text(
                isArabic ? 'الديون والالتزامات المستحقة المخصومة شرعاً ($currency)' : 'Deductible Short-Term Debts ($currency)',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: TextField(
                  controller: _liabilitiesController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  style: AppTheme.amountMonospace(fontSize: 16, color: AppTheme.terracotta),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: AppTheme.amountMonospace(fontSize: 16, color: AppTheme.inkMuted),
                    border: InputBorder.none,
                    prefixText: '- $currency ',
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Hawl Start Date & Lunar Period Indicator
              Text(
                isArabic ? 'تاريخ بدء الحول (بلوغ النصاب)' : 'Hawl Lunar Holding Start Date',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickHawlDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.creamBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isHawlMet ? Icons.verified_rounded : Icons.schedule_rounded,
                        size: 18,
                        color: isHawlMet ? AppTheme.primaryTeal : AppTheme.accentGold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('d MMMM yyyy', isArabic ? 'ar' : 'en').format(_hawlStartDate),
                          style: AppTheme.body(fontSize: 13, lang: lang),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isHawlMet ? AppTheme.primaryTealLight : AppTheme.accentGoldLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isHawlMet
                              ? (isArabic ? 'اكتمل الحول 🌙' : 'Hawl Completed 🌙')
                              : (isArabic ? 'متبقي ${354 - daysElapsed} يوم' : '${354 - daysElapsed}d remaining'),
                          style: AppTheme.label(
                            fontSize: 10,
                            color: isHawlMet ? AppTheme.primaryTeal : AppTheme.accentGold,
                            lang: lang,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Member Attribution (Owner)
              Text(
                isArabic ? 'ملكية الأصل' : 'Asset Ownership',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedMemberId = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedMemberId == null ? AppTheme.primaryTealLight : AppTheme.creamBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedMemberId == null ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                        ),
                      ),
                      child: Text(
                        isArabic ? 'مشترك للأسرة' : 'Household Pooled',
                        style: AppTheme.body(
                          fontSize: 12,
                          color: _selectedMemberId == null ? AppTheme.primaryTealDark : AppTheme.inkPrimary,
                          lang: lang,
                        ),
                      ),
                    ),
                  ),
                  ..._members.map((m) {
                    final isSelected = _selectedMemberId == m.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMemberId = m.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryTealLight : AppTheme.creamBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryTeal : AppTheme.surfaceBorder,
                          ),
                        ),
                        child: Text(
                          m.name,
                          style: AppTheme.body(
                            fontSize: 12,
                            color: isSelected ? AppTheme.primaryTealDark : AppTheme.inkPrimary,
                            lang: lang,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // Net Zakatable Value Summary Badge
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentGoldLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentGoldBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'الوعاء الزكوي الصافي للأصل:' : 'Net Zakatable Asset Value:',
                      style: AppTheme.bodyMedium(fontSize: 13, color: AppTheme.accentGold, lang: lang),
                    ),
                    Text(
                      '${NumberFormat('#,##0.00').format(netZakatable)} $currency',
                      style: AppTheme.amountMonospace(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveAsset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isNew ? (isArabic ? 'إضافة الأصل' : 'Add Asset') : (isArabic ? 'حفظ التعديلات' : 'Save Changes'),
                  style: AppTheme.bodyMedium(fontSize: 16, color: Colors.white, lang: lang),
                ),
              ),

              if (!isNew) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _deleteAsset,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.terracotta),
                  child: Text(
                    isArabic ? 'حذف هذا الأصل الزكوي' : 'Delete This Asset',
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
