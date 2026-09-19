import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/receipt.dart';
import '../services/database_service.dart';
import '../services/ai_scanner_service.dart';
import '../services/paywall_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';
import 'verification_screen.dart';
import 'paywall_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onAddReceipt;

  const DashboardScreen({super.key, required this.onAddReceipt});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  final PaywallService _paywallService = PaywallService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  String? _insight;
  bool _isLoadingInsight = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
    _generateInsightIfAvailable();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptCategoryPersonalization();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _checkAndPromptCategoryPersonalization() {
    if (_dbService.getReceiptCount() > 0 && !_dbService.hasSeenCategoryPrompt) {
      _showPersonalizationSheet();
    }
  }

  void _showPersonalizationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.paperBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
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
                const SizedBox(height: 18),
                Text(
                  'Tailor Your Expense Categories',
                  style: AppTheme.editorialHeading.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'What best describes your primary freelance or business work?',
                  style: AppTheme.body.copyWith(color: AppTheme.inkSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildRoleOption(
                  ctx,
                  title: '💻 Software & Technology',
                  subtitle: 'Software, Hardware, Internet, Home Office',
                  categories: ['Software', 'Hardware', 'Office', 'Utilities', 'Other'],
                  role: 'tech',
                ),
                _buildRoleOption(
                  ctx,
                  title: '🚗 Rideshare & Delivery',
                  subtitle: 'Fuel, Vehicle Maintenance, Phone, Meals',
                  categories: ['Fuel', 'Maintenance', 'Meals', 'Utilities', 'Other'],
                  role: 'rideshare',
                ),
                _buildRoleOption(
                  ctx,
                  title: '🎨 Design & Creative',
                  subtitle: 'Software, Subscriptions, Equipment, Travel',
                  categories: ['Software', 'Travel', 'Meals', 'Office', 'Other'],
                  role: 'creative',
                ),
                _buildRoleOption(
                  ctx,
                  title: '💼 General Freelance / Consultant',
                  subtitle: 'Meals, Travel, Software, Office, Utilities',
                  categories: ['Meals', 'Travel', 'Software', 'Office', 'Utilities', 'Other'],
                  role: 'general',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleOption(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required List<String> categories,
    required String role,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () async {
          await _dbService.setUserRole(role);
          await _dbService.setActiveCategories(categories);
          await _dbService.setHasSeenCategoryPrompt(true);
          if (ctx.mounted) Navigator.of(ctx).pop();
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.bodyMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTheme.body.copyWith(fontSize: 12, color: AppTheme.inkSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateInsightIfAvailable() async {
    final ledger = _dbService.getAllReceipts();
    if (ledger.isEmpty) {
      if (mounted) setState(() => _insight = null);
      return;
    }

    setState(() => _isLoadingInsight = true);

    try {
      final response = await AiScannerService().askAssistant(
        "Give a 1-sentence quick financial insight or tax deduction tip based on these expenses. Keep it concise, helpful, and grounded.",
        ledger,
      );
      if (mounted) {
        setState(() {
          _insight = response;
          _isLoadingInsight = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInsight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Receipt>>(
      valueListenable: _dbService.listenable,
      builder: (context, box, _) {
        final allReceipts = box.values.toList().reversed.toList();

        if (allReceipts.isEmpty) {
          return _buildEmptyState(context);
        }

        final filteredReceipts = allReceipts.where((r) {
          final matchesCategory = _selectedCategory == 'All' ||
              (r.category != null && r.category!.toLowerCase() == _selectedCategory.toLowerCase());
          final matchesSearch = _searchQuery.isEmpty ||
              (r.vendorName != null && r.vendorName!.toLowerCase().contains(_searchQuery));
          return matchesCategory && matchesSearch;
        }).toList();

        final filteredTotal = filteredReceipts.fold<double>(
          0.0,
          (sum, r) => sum + (r.totalAmount ?? 0.0),
        );

        final categories = ['All', ..._dbService.activeCategories];

        return RefreshIndicator(
          onRefresh: _generateInsightIfAvailable,
          color: AppTheme.pinePrimary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. AI Insight Card
              if (_insight != null || _isLoadingInsight)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.pineBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.pineDark.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.pineLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.pinePrimary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "LEDGER INSIGHT",
                              style: AppTheme.tagText.copyWith(color: AppTheme.pinePrimary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoadingInsight
                                  ? "Analyzing ledger records..."
                                  : (_insight ?? ""),
                              style: AppTheme.body.copyWith(
                                color: AppTheme.inkPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Paywall Upsell / Usage Meter (Strict 10 Free Scans)
              ValueListenableBuilder<bool>(
                valueListenable: _paywallService.isPro,
                builder: (context, isPro, _) {
                  if (isPro) return const SizedBox.shrink();
                  final count = allReceipts.length;
                  const maxScans = DatabaseService.maxFreeScans;
                  final isLimitReached = count >= maxScans;

                  return Pressable(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaywallScreen()),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isLimitReached ? const Color(0xFFFEF2F2) : AppTheme.ochreLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLimitReached ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLimitReached ? Icons.lock_outline_rounded : Icons.bolt_rounded,
                            color: isLimitReached ? AppTheme.terracotta : AppTheme.ochreAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isLimitReached ? "Free Evaluation Scan Used" : "1 Free Evaluation Scan Available",
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: isLimitReached ? AppTheme.terracotta : AppTheme.inkPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      isLimitReached ? "Unlock Pro" : "Upgrade",
                                      style: AppTheme.tagText.copyWith(
                                        color: isLimitReached ? AppTheme.terracotta : AppTheme.ochreAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 11,
                                      color: isLimitReached ? AppTheme.terracotta : AppTheme.ochreAccent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isLimitReached
                                      ? "Evaluation scan complete. Unlock DashTally Pro for unlimited scans."
                                      : "Test OCR on crumpled truck receipts. Tap to unlock unlimited scans.",
                                  style: AppTheme.body.copyWith(fontSize: 12, color: AppTheme.inkSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // 3. Live Search Bar
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search merchant or vendor...",
                    hintStyle: AppTheme.body.copyWith(color: AppTheme.inkMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.inkSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.inkMuted),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              // 4. Horizontal Category Filter Chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategory == cat;

                    return Pressable(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.pinePrimary : AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? AppTheme.pinePrimary : AppTheme.surfaceBorder,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: AppTheme.tagText.copyWith(
                            color: isSelected ? Colors.white : AppTheme.inkPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 5. Summary Header bar
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == 'All' && _searchQuery.isEmpty
                          ? "${allReceipts.length} ${allReceipts.length == 1 ? 'RECORD' : 'RECORDS'}"
                          : "SHOWING ${filteredReceipts.length} OF ${allReceipts.length}",
                      style: AppTheme.sectionHeading,
                    ),
                    Text(
                      "TOTAL: \$${filteredTotal.toStringAsFixed(2)}",
                      style: AppTheme.amountMonospace.copyWith(fontSize: 14, color: AppTheme.inkSecondary),
                    ),
                  ],
                ),
              ),

              // 6. Receipts List
              if (filteredReceipts.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.filter_alt_off_outlined, size: 36, color: AppTheme.inkMuted),
                      const SizedBox(height: 8),
                      Text("No matching receipts found", style: AppTheme.body.copyWith(color: AppTheme.inkSecondary)),
                    ],
                  ),
                )
              else
                ...filteredReceipts.map((receipt) {
                  final isFailed = receipt.vendorName == null && receipt.totalAmount == null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Pressable(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VerificationScreen(receipt: receipt),
                          ),
                        ).then((_) => _generateInsightIfAvailable());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isFailed ? const Color(0xFFFEE2E2) : AppTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isFailed ? Icons.error_outline_rounded : Icons.receipt_long_outlined,
                                color: isFailed ? AppTheme.terracotta : AppTheme.pinePrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isFailed ? "Incomplete Scan" : (receipt.vendorName ?? "Unknown Vendor"),
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: isFailed ? AppTheme.terracotta : AppTheme.inkPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        receipt.category ?? 'General',
                                        style: AppTheme.tagText.copyWith(color: AppTheme.inkMuted),
                                      ),
                                      if (receipt.date != null) ...[
                                        const Text(" • ", style: TextStyle(color: AppTheme.inkMuted)),
                                        Text(
                                          "${receipt.date!.month}/${receipt.date!.day}/${receipt.date!.year}",
                                          style: AppTheme.tagText.copyWith(color: AppTheme.inkMuted),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              isFailed
                                  ? "Review"
                                  : (receipt.totalAmount != null
                                      ? "\$${receipt.totalAmount!.toStringAsFixed(2)}"
                                      : "--"),
                              style: isFailed
                                  ? AppTheme.tagText.copyWith(color: AppTheme.terracotta, fontWeight: FontWeight.bold)
                                  : AppTheme.amountMonospace.copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.pineLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.pineBorder, width: 1.5),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.pinePrimary,
              size: 32,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            "Expense tracking made effortless",
            textAlign: TextAlign.center,
            style: AppTheme.editorialHeading.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 10),
          Text(
            "Capture receipts, extract totals, and produce clean CSV records ready for your taxes.",
            textAlign: TextAlign.center,
            style: AppTheme.body,
          ),
          const SizedBox(height: 28),

          _buildValueStep(
            icon: Icons.camera_alt_outlined,
            title: "Multi-page & Digital Scan",
            description: "Capture long grocery slips across multiple snaps or import digital screenshots.",
          ),
          const SizedBox(height: 10),
          _buildValueStep(
            icon: Icons.shield_outlined,
            title: "Private On-Device OCR",
            description: "Photos never leave your phone. Text extraction runs locally on your device.",
          ),
          const SizedBox(height: 10),
          _buildValueStep(
            icon: Icons.table_chart_outlined,
            title: "Instant CSV Export",
            description: "Generate clean spreadsheets ready for Excel, Google Sheets, or your accountant.",
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.pinePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: widget.onAddReceipt,
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              label: Text(
                "Add Your First Receipt",
                style: AppTheme.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VerificationScreen(
                    receipt: Receipt(
                      localImagePath: '',
                      syncStatus: 'draft',
                    ),
                  ),
                ),
              );
            },
            child: Text(
              "Or enter an expense manually",
              style: AppTheme.tagText.copyWith(
                color: AppTheme.pinePrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildValueStep({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.pinePrimary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.bodyMedium.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(description, style: AppTheme.body.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
