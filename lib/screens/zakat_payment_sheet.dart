import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:uuid/uuid.dart';

import '../models/household.dart';
import '../models/member.dart';
import '../models/zakat_payment.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class ZakatPaymentSheet extends StatefulWidget {
  final Household household;
  final String obligationPeriod;

  const ZakatPaymentSheet({
    super.key,
    required this.household,
    required this.obligationPeriod,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Household household,
    required String obligationPeriod,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ZakatPaymentSheet(
          household: household,
          obligationPeriod: obligationPeriod,
        ),
      ),
    );
  }

  @override
  State<ZakatPaymentSheet> createState() => _ZakatPaymentSheetState();
}

class _ZakatPaymentSheetState extends State<ZakatPaymentSheet> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  String? _selectedMemberId;
  List<Member> _members = [];

  final List<String> _recipientPresetsAr = [
    'قطر الخيرية',
    'الهلال الأحمر',
    'منصة إحسان',
    'أسرة متعففة',
    'تراحم',
    'مباشر للمستحقين',
  ];

  final List<String> _recipientPresetsEn = [
    'Qatar Charity',
    'Red Crescent',
    'Ehsan Platform',
    'Eligible Family',
    'Local Beneficiary',
  ];

  @override
  void initState() {
    super.initState();
    _members = _db.getMembers();
    if (_members.isNotEmpty) {
      _selectedMemberId = _members.firstWhere((m) => m.isPrimary, orElse: () => _members.first).id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  void _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(rawAmount);

    if (amount == null || amount <= 0) return;

    final payment = ZakatPayment(
      id: const Uuid().v4(),
      householdId: widget.household.id,
      memberId: _selectedMemberId,
      obligationPeriod: widget.obligationPeriod,
      amount: amount,
      paymentDate: _paymentDate,
      recipient: _recipientController.text.trim().isEmpty ? null : _recipientController.text.trim(),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    await _db.addZakatPayment(payment);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.household.preferredLanguage == 'ar';
    final lang = widget.household.preferredLanguage;
    final currency = isArabic ? widget.household.currencySymbol : widget.household.currencyCode;
    final presets = isArabic ? _recipientPresetsAr : _recipientPresetsEn;

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
                    isArabic ? 'تسجيل دفعة زكاة' : 'Record Zakat Payment',
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

              // Amount Input
              Text(
                isArabic ? 'مبلغ الزكاة المدفوع *' : 'Zakat Amount Paid *',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentGoldBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    Text(
                      currency,
                      style: AppTheme.amountMonospace(fontSize: 18, color: AppTheme.accentGold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return isArabic ? 'يرجى إدخال المبلغ' : 'Please enter amount';
                          }
                          final parsed = double.tryParse(v.trim().replaceAll(',', ''));
                          if (parsed == null || parsed <= 0) {
                            return isArabic ? 'مبلغ غير صالح' : 'Invalid amount';
                          }
                          return null;
                        },
                        style: AppTheme.amountMonospace(fontSize: 26, color: AppTheme.inkPrimary),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: AppTheme.amountMonospace(fontSize: 26, color: AppTheme.inkMuted),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Recipient / Beneficiary
              Text(
                isArabic ? 'الجهة المستلمة / المستحق' : 'Recipient Entity / Beneficiary',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _recipientController,
                style: AppTheme.body(fontSize: 14, lang: lang),
                decoration: InputDecoration(
                  hintText: isArabic ? 'مثال: قطر الخيرية / أسرة متعففة' : 'e.g. Red Crescent / Local Family',
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
              const SizedBox(height: 8),

              // Presets
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets.map((p) {
                  return GestureDetector(
                    onTap: () => setState(() => _recipientController.text = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p,
                        style: AppTheme.body(fontSize: 11, color: AppTheme.inkSecondary, lang: lang),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Payment Date & Payer
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'تاريخ الدفع' : 'Payment Date',
                          style: AppTheme.label(fontSize: 12, lang: lang),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickDate,
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
                                    DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en').format(_paymentDate),
                                    style: AppTheme.body(fontSize: 12, lang: lang),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'المساهم الدافع' : 'Payer Attribution',
                          style: AppTheme.label(fontSize: 12, lang: lang),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.creamBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.surfaceBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedMemberId,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    isArabic ? 'الأسرة مجتمعة' : 'Household',
                                    style: AppTheme.body(fontSize: 12, lang: lang),
                                  ),
                                ),
                                ..._members.map((m) => DropdownMenuItem<String?>(
                                      value: m.id,
                                      child: Text(
                                        m.name,
                                        style: AppTheme.body(fontSize: 12, lang: lang),
                                      ),
                                    )),
                              ],
                              onChanged: (val) => setState(() => _selectedMemberId = val),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Note
              Text(
                isArabic ? 'ملاحظات إضافية (اختياري)' : 'Notes (Optional)',
                style: AppTheme.label(fontSize: 12, lang: lang),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                style: AppTheme.body(fontSize: 13, lang: lang),
                decoration: InputDecoration(
                  hintText: isArabic ? 'مثال: سداد كفارة أو دفعة مقدمة' : 'e.g. Advance payment',
                  filled: true,
                  fillColor: AppTheme.creamBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _savePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isArabic ? 'تسجيل الدفعة' : 'Save Zakat Payment',
                  style: AppTheme.bodyMedium(fontSize: 16, color: Colors.white, lang: lang),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
