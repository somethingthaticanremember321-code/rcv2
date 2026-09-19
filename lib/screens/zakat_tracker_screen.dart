import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/household.dart';
import '../models/member.dart';
import '../models/zakat_asset.dart';
import '../models/zakat_payment.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'nisab_settings_dialog.dart';
import 'zakat_asset_sheet.dart';
import 'zakat_payment_sheet.dart';

class ZakatTrackerScreen extends StatefulWidget {
  const ZakatTrackerScreen({super.key});

  @override
  State<ZakatTrackerScreen> createState() => _ZakatTrackerScreenState();
}

class _ZakatTrackerScreenState extends State<ZakatTrackerScreen> {
  final DatabaseService _db = DatabaseService();
  late Household _household;
  String _selectedPeriod = '1447 AH';
  int _activeSegmentIndex = 0; // 0: Assets, 1: Payments

  final List<Map<String, String>> _periods = [
    {'id': '1447 AH', 'labelAr': '١٤٤٧ هـ (٢٠٢٦ م)', 'labelEn': '1447 AH (2026)'},
    {'id': '1446 AH', 'labelAr': '١٤٤٦ هـ (٢٠٢٥ م)', 'labelEn': '1446 AH (2025)'},
  ];

  @override
  void initState() {
    super.initState();
    _household = _db.getHousehold();
  }

  void _reload() {
    setState(() {
      _household = _db.getHousehold();
    });
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '${formatter.format(amount)} ${_household.currencySymbol}';
  }

  IconData _getAssetIcon(String type) {
    switch (type) {
      case 'gold':
        return Icons.monetization_on_outlined;
      case 'silver':
        return Icons.circle_outlined;
      case 'investments':
        return Icons.trending_up_rounded;
      case 'trade_goods':
        return Icons.storefront_outlined;
      case 'cash':
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  void _openNisabDialog() async {
    final updated = await NisabSettingsDialog.show(context, household: _household);
    if (updated == true && mounted) {
      _reload();
    }
  }

  void _openAssetSheet([ZakatAsset? asset]) async {
    final updated = await ZakatAssetSheet.show(
      context,
      household: _household,
      existingAsset: asset,
    );
    if (updated == true && mounted) {
      setState(() {});
    }
  }

  void _openPaymentSheet() async {
    final updated = await ZakatPaymentSheet.show(
      context,
      household: _household,
      obligationPeriod: _selectedPeriod,
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
            isArabic ? 'حساب الزكاة الشرعي' : 'Shariah Zakat Tracker',
            style: AppTheme.brandTitle(lang: lang),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: AppTheme.accentGold),
              tooltip: isArabic ? 'إعدادات النصاب' : 'Nisab Settings',
              onPressed: _openNisabDialog,
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _db.zakatAssetListenable,
              _db.zakatPaymentListenable,
            ]),
            builder: (context, _) {
              final summary = _db.getZakatObligationSummary(obligationPeriod: _selectedPeriod);
              final assets = _db.getZakatAssets();
              final payments = _db.getZakatPayments(obligationPeriod: _selectedPeriod);
              final members = {for (var m in _db.getMembers()) m.id: m};

              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 6)),

                  // Period & Nisab Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildNisabHeader(summary, lang),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // Obligation Hero Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildObligationHero(summary, lang),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // Segmented Control (Assets vs Payments)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSegmentSwitcher(assets.length, payments.length, lang),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // Content List
                  if (_activeSegmentIndex == 0) ...[
                    // Assets List
                    if (assets.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildEmptyState(
                          title: isArabic ? 'لا توجد أصول زكوية مسجلة' : 'No zakatable assets added',
                          desc: isArabic
                              ? 'أضف السيولة النقدية، الذهب، والاستثمارات لاحتساب الزكاة تلقائياً'
                              : 'Add cash, gold, and investment holdings to calculate zakat',
                          buttonText: isArabic ? 'إضافة أصل زكوي' : 'Add Zakatable Asset',
                          onTap: () => _openAssetSheet(),
                          lang: lang,
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final asset = assets[index];
                              final member = asset.memberId != null ? members[asset.memberId] : null;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildAssetTile(asset, member, lang),
                              );
                            },
                            childCount: assets.length,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => _openAssetSheet(),
                            icon: const Icon(Icons.add, color: AppTheme.accentGold, size: 18),
                            label: Text(
                              isArabic ? 'إضافة أصل زكوي جديد' : 'Add New Zakatable Asset',
                              style: AppTheme.bodyMedium(fontSize: 14, color: AppTheme.accentGold, lang: lang),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppTheme.accentGoldBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: AppTheme.surfaceCard,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Payments List
                    if (payments.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildEmptyState(
                          title: isArabic ? 'لم تُسجل دفعات زكاة لهذا الحول' : 'No zakat payments logged',
                          desc: isArabic
                              ? 'سجّل التبرعات والمصارف الشرعية المخرجة لخصمها من الواجب'
                              : 'Record payments made to charities to track your remaining obligation',
                          buttonText: isArabic ? 'تسجيل دفعة زكاة' : 'Record Zakat Payment',
                          onTap: _openPaymentSheet,
                          lang: lang,
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final payment = payments[index];
                              final member = payment.memberId != null ? members[payment.memberId] : null;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildPaymentTile(payment, member, lang),
                              );
                            },
                            childCount: payments.length,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: OutlinedButton.icon(
                            onPressed: _openPaymentSheet,
                            icon: const Icon(Icons.add, color: AppTheme.accentGold, size: 18),
                            label: Text(
                              isArabic ? 'تسجيل دفعة زكاة جديدة' : 'Record Another Payment',
                              style: AppTheme.bodyMedium(fontSize: 14, color: AppTheme.accentGold, lang: lang),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppTheme.accentGoldBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: AppTheme.surfaceCard,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildNisabHeader(ZakatObligationSummary summary, String lang) {
    final isArabic = lang == 'ar';
    final isGold = summary.nisabStandard == 'gold_85g';
    final standardLabel = isGold
        ? (isArabic ? 'معيار الذهب (٨٥غ)' : 'Gold 85g Standard')
        : (isArabic ? 'معيار الفضة (٥٩٥غ)' : 'Silver 595g Standard');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGoldLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.balance_rounded, color: AppTheme.accentGold, size: 16),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    standardLabel,
                    style: AppTheme.label(fontSize: 11, color: AppTheme.inkSecondary, lang: lang),
                  ),
                  Text(
                    '${isArabic ? "النصاب:" : "Nisab:"} ${_formatCurrency(summary.nisabThreshold)}',
                    style: AppTheme.amountMonospace(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.inkPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Period Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.creamBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                items: _periods.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['id'],
                    child: Text(
                      isArabic ? p['labelAr']! : p['labelEn']!,
                      style: AppTheme.bodyMedium(fontSize: 11, color: AppTheme.inkPrimary, lang: lang),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPeriod = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObligationHero(ZakatObligationSummary summary, String lang) {
    final isArabic = lang == 'ar';
    final isMet = summary.isNisabMet;
    final progress = summary.totalZakatDue > 0
        ? (summary.totalZakatPaid / summary.totalZakatDue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isMet ? AppTheme.accentGoldBorder : AppTheme.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Subtitle + Nisab Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الزكاة الواجبة شرعاً (٢.٥٪)' : 'Zakat Obligation (2.5%)',
                style: AppTheme.label(fontSize: 13, color: AppTheme.inkSecondary, lang: lang),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMet ? AppTheme.accentGoldLight : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isMet
                      ? (isArabic ? 'بلغ النصاب (واجبة 🌙)' : 'Nisab Reached (Obligatory)')
                      : (isArabic ? 'دون النصاب (غير واجبة)' : 'Below Nisab'),
                  style: AppTheme.label(
                    fontSize: 11,
                    color: isMet ? AppTheme.accentGold : AppTheme.inkMuted,
                    lang: lang,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Zakat Due Number
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              _formatCurrency(summary.totalZakatDue),
              style: AppTheme.amountMonospace(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: isMet ? AppTheme.accentGold : AppTheme.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Progress bar of paid vs due
          if (summary.totalZakatDue > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppTheme.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  summary.isObligationFulfilled ? AppTheme.primaryTeal : AppTheme.accentGold,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          const Divider(height: 1, color: AppTheme.surfaceBorder),
          const SizedBox(height: 12),

          // Sub metrics: Gross Assets, Deductible Liabilities, Paid, Remaining
          Row(
            children: [
              // Net Zakatable Wealth
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الوعاء الصافي' : 'Net Zakatable',
                      style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(summary.netZakatableWealth),
                      style: AppTheme.amountMonospace(fontSize: 13, color: AppTheme.inkPrimary),
                    ),
                  ],
                ),
              ),

              Container(height: 24, width: 1, color: AppTheme.surfaceBorder),

              // Paid
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'المدفوع' : 'Paid',
                        style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(summary.totalZakatPaid),
                        style: AppTheme.amountMonospace(fontSize: 13, color: AppTheme.primaryTeal),
                      ),
                    ],
                  ),
                ),
              ),

              Container(height: 24, width: 1, color: AppTheme.surfaceBorder),

              // Remaining Due
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'المتبقي' : 'Remaining',
                        style: AppTheme.label(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(summary.remainingZakatOwed),
                        style: AppTheme.amountMonospace(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: summary.remainingZakatOwed > 0 ? AppTheme.accentGold : AppTheme.primaryTeal,
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

  Widget _buildSegmentSwitcher(int assetCount, int paymentCount, String lang) {
    final isArabic = lang == 'ar';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegmentIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeSegmentIndex == 0 ? AppTheme.accentGoldLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeSegmentIndex == 0 ? AppTheme.accentGoldBorder : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${isArabic ? "الأصول الزكوية" : "Assets"} ($assetCount)',
                  style: AppTheme.bodyMedium(
                    fontSize: 13,
                    color: _activeSegmentIndex == 0 ? AppTheme.accentGold : AppTheme.inkSecondary,
                    lang: lang,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegmentIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeSegmentIndex == 1 ? AppTheme.accentGoldLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeSegmentIndex == 1 ? AppTheme.accentGoldBorder : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${isArabic ? "سجل الدفعات" : "Payments"} ($paymentCount)',
                  style: AppTheme.bodyMedium(
                    fontSize: 13,
                    color: _activeSegmentIndex == 1 ? AppTheme.accentGold : AppTheme.inkSecondary,
                    lang: lang,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTile(ZakatAsset asset, Member? member, String lang) {
    final isArabic = lang == 'ar';
    final daysElapsed = asset.hawlStartDate != null
        ? DateTime.now().difference(asset.hawlStartDate!).inDays
        : 354;
    final isHawlMet = daysElapsed >= 354;

    return Dismissible(
      key: Key(asset.id),
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
      onDismissed: (_) async {
        await _db.deleteZakatAsset(asset.id);
      },
      child: GestureDetector(
        onTap: () => _openAssetSheet(asset),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGoldLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getAssetIcon(asset.assetType), size: 20, color: AppTheme.accentGold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            asset.name,
                            style: AppTheme.bodyMedium(fontSize: 14, lang: lang),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              member.name,
                              style: AppTheme.label(fontSize: 9, color: AppTheme.inkSecondary, lang: lang),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (asset.weightGrams != null) ...[
                          Text(
                            '${asset.weightGrams!.toStringAsFixed(1)}g ${asset.purityKarat != null ? "(${asset.purityKarat}K)" : ""}',
                            style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                          ),
                          const SizedBox(width: 6),
                          Text('•', style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: lang)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          isHawlMet ? (isArabic ? 'اكتمل الحول 🌙' : 'Hawl met') : '${354 - daysElapsed}d left',
                          style: AppTheme.body(
                            fontSize: 11,
                            color: isHawlMet ? AppTheme.primaryTeal : AppTheme.accentGold,
                            lang: lang,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(asset.netZakatableValue),
                    style: AppTheme.amountMonospace(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkPrimary,
                    ),
                  ),
                  if (asset.deductibleLiabilities > 0)
                    Text(
                      '-${_formatCurrency(asset.deductibleLiabilities)}',
                      style: AppTheme.amountMonospace(fontSize: 10, color: AppTheme.terracotta),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTile(ZakatPayment payment, Member? member, String lang) {
    final isArabic = lang == 'ar';

    return Dismissible(
      key: Key(payment.id),
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
      onDismissed: (_) async {
        await _db.deleteZakatPayment(payment.id);
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryTealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.volunteer_activism_rounded, size: 20, color: AppTheme.primaryTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.recipient ?? (isArabic ? 'دفعة زكاة' : 'Zakat Payment'),
                    style: AppTheme.bodyMedium(fontSize: 14, lang: lang),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        DateFormat('d MMM yyyy', isArabic ? 'ar' : 'en').format(payment.paymentDate),
                        style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: lang),
                      ),
                      if (member != null) ...[
                        const SizedBox(width: 6),
                        Text('•', style: AppTheme.body(fontSize: 11, color: AppTheme.inkMuted, lang: lang)),
                        const SizedBox(width: 6),
                        Text(member.name, style: AppTheme.body(fontSize: 11, color: AppTheme.inkSecondary, lang: lang)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _formatCurrency(payment.amount),
              style: AppTheme.amountMonospace(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String desc,
    required String buttonText,
    required VoidCallback onTap,
    required String lang,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: const Icon(
                Icons.balance_rounded,
                size: 38,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.editorialHeading(fontSize: 18, lang: lang),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: AppTheme.body(fontSize: 13, color: AppTheme.inkMuted, lang: lang),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                buttonText,
                style: AppTheme.bodyMedium(fontSize: 14, color: Colors.white, lang: lang),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
