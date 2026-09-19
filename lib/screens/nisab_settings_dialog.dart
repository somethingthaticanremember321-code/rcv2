import 'package:flutter/material.dart';

import '../models/household.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class NisabSettingsDialog extends StatefulWidget {
  final Household household;

  const NisabSettingsDialog({
    super.key,
    required this.household,
  });

  static Future<bool?> show(BuildContext context, {required Household household}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => NisabSettingsDialog(household: household),
    );
  }

  @override
  State<NisabSettingsDialog> createState() => _NisabSettingsDialogState();
}

class _NisabSettingsDialogState extends State<NisabSettingsDialog> {
  final DatabaseService _db = DatabaseService();
  late TextEditingController _goldPriceController;
  late TextEditingController _silverPriceController;
  late String _selectedStandard;

  @override
  void initState() {
    super.initState();
    _selectedStandard = widget.household.nisabStandard;
    _goldPriceController = TextEditingController(
      text: (widget.household.cachedGoldPricePerGram ?? 320.0).toStringAsFixed(1),
    );
    _silverPriceController = TextEditingController(
      text: (widget.household.cachedSilverPricePerGram ?? 4.0).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _goldPriceController.dispose();
    _silverPriceController.dispose();
    super.dispose();
  }

  void _save() async {
    final goldPrice = double.tryParse(_goldPriceController.text.trim()) ?? 320.0;
    final silverPrice = double.tryParse(_silverPriceController.text.trim()) ?? 4.0;

    final updated = widget.household.copyWith(
      nisabStandard: _selectedStandard,
      cachedGoldPricePerGram: goldPrice,
      cachedSilverPricePerGram: silverPrice,
      pricesUpdatedAt: DateTime.now(),
    );

    await _db.updateHousehold(updated);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.household.preferredLanguage == 'ar';
    final lang = widget.household.preferredLanguage;
    final currency = isArabic ? widget.household.currencySymbol : widget.household.currencyCode;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentGoldLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: AppTheme.accentGold, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isArabic ? 'معيار النصاب وأسعار الذهب' : 'Nisab Standard & Spot Prices',
                style: AppTheme.editorialHeading(fontSize: 18, lang: lang),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isArabic
                    ? 'يُحسب النصاب الشرعي بناءً على القيمة الحالية لـ ٨٥غ من الذهب الخالص (عيار ٢٤) أو ٥٩٥غ من الفضة.'
                    : 'Nisab is calculated based on the market value of 85g fine gold (24K) or 595g pure silver.',
                style: AppTheme.body(fontSize: 12, color: AppTheme.inkSecondary, lang: lang),
              ),
              const SizedBox(height: 18),

              // Standard selection
              Text(
                isArabic ? 'المعيار المعتمد للنصاب:' : 'Nisab Standard:',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedStandard = 'gold_85g'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedStandard == 'gold_85g'
                              ? AppTheme.accentGoldLight
                              : AppTheme.creamBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedStandard == 'gold_85g'
                                ? AppTheme.accentGold
                                : AppTheme.surfaceBorder,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isArabic ? 'الذهب (٨٥غ) - معتمد' : 'Gold (85g) - Standard',
                          style: AppTheme.bodyMedium(
                            fontSize: 11,
                            color: _selectedStandard == 'gold_85g'
                                ? AppTheme.accentGold
                                : AppTheme.inkPrimary,
                            lang: lang,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedStandard = 'silver_595g'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedStandard == 'silver_595g'
                              ? AppTheme.primaryTealLight
                              : AppTheme.creamBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedStandard == 'silver_595g'
                                ? AppTheme.primaryTeal
                                : AppTheme.surfaceBorder,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isArabic ? 'الفضة (٥٩٥غ)' : 'Silver (595g)',
                          style: AppTheme.bodyMedium(
                            fontSize: 11,
                            color: _selectedStandard == 'silver_595g'
                                ? AppTheme.primaryTeal
                                : AppTheme.inkPrimary,
                            lang: lang,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Gold Spot Price
              Text(
                isArabic ? 'سعر غرام الذهب عيار ٢٤ ($currency):' : 'Gold Spot Price (24K / gram in $currency):',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: TextField(
                  controller: _goldPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTheme.amountMonospace(fontSize: 16, color: AppTheme.inkPrimary),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
              const SizedBox(height: 14),

              // Silver Spot Price
              Text(
                isArabic ? 'سعر غرام الفضة ($currency):' : 'Silver Spot Price (per gram in $currency):',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: TextField(
                  controller: _silverPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTheme.amountMonospace(fontSize: 16, color: AppTheme.inkPrimary),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isArabic ? 'حفظ المعايير' : 'Save Standard'),
          ),
        ],
      ),
    );
  }
}
