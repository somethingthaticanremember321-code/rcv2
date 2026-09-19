import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/paywall_service.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];
  Package? _selectedPackage;
  String _selectedFallback = 'annual'; // 'monthly', 'annual', 'lifetime'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService().paywallImpression(
      trigger: 'hard_gate_10_scans',
      attemptsUsed: DatabaseService().getReceiptCount(),
      savedReceiptCount: DatabaseService().getReceiptCount(),
    );
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final packages = await PaywallService().getPackages();
    if (mounted) {
      setState(() {
        _packages = packages;
        if (packages.isNotEmpty) {
          // Default to Annual plan as anchor
          _selectedPackage = packages.firstWhere(
            (p) => p.packageType == PackageType.annual,
            orElse: () => packages.firstWhere(
              (p) => p.packageType == PackageType.lifetime,
              orElse: () => packages.first,
            ),
          );
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _purchase() async {
    final planType = _selectedPackage != null
        ? _selectedPackage!.packageType.name
        : _selectedFallback;

    if (_selectedPackage != null) {
      setState(() => _isLoading = true);
      final success = await PaywallService().purchasePro(_selectedPackage!);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        AnalyticsService().purchaseCompleted(planType: planType);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Welcome to Pro! Unlimited scans unlocked.')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase could not be completed.')),
        );
      }
    } else {
      // Test fallback mode
      _testUnlock(planType);
    }
  }

  void _testUnlock(String planType) {
    PaywallService().isPro.value = true;
    AnalyticsService().purchaseCompleted(planType: planType);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pro unlocked! Unlimited scans active.')),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    final success = await PaywallService().restorePurchases();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchases restored successfully!')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active purchases found to restore.')),
      );
    }
  }

  String _getPackageTitle(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 'Annual Plan';
      case PackageType.monthly:
        return 'Monthly Plan';
      case PackageType.lifetime:
        return 'Lifetime Pro';
      default:
        return p.storeProduct.title;
    }
  }

  String _getPackageSubtitle(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 'Billed annually • Just \$2.50 / month';
      case PackageType.monthly:
        return 'Billed monthly • Cancel anytime';
      case PackageType.lifetime:
        return 'Pay once, keep forever • Zero subscriptions';
      default:
        return p.storeProduct.description;
    }
  }

  String? _getPackageBadge(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 'BEST VALUE • SAVE 50%';
      case PackageType.lifetime:
        return 'ONE-TIME PURCHASE';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paperBg,
      appBar: AppBar(
        title: Text('DashTally Pro', style: AppTheme.brandTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Outcome Headline
              Text(
                'Turn a shoebox of receipts into a clean spreadsheet in minutes.',
                textAlign: TextAlign.center,
                style: AppTheme.editorialHeading.copyWith(
                  fontSize: 24,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Extract vendor, date, tax, and totals with on-device OCR and AI.',
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(
                  color: AppTheme.inkSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // 2. Truthful Value Proposition Cards
              _buildFeatureRow(
                icon: Icons.auto_awesome_rounded,
                title: 'Multi-Page Smart Scanning',
                subtitle: 'Combine long accordion receipts into a single clean record.',
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(
                icon: Icons.table_view_rounded,
                title: 'One-Tap Clean CSV Export',
                subtitle: 'Structured spreadsheets ready for Excel, Google Sheets, or your accountant.',
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(
                icon: Icons.lock_outline_rounded,
                title: 'Private Photo Processing',
                subtitle: 'Receipt photos are processed locally via on-device ML Kit. Extracted text is sent over an encrypted TLS connection solely for data structuring — photos never leave your device.',
              ),
              const SizedBox(height: 24),

              // 3. Plan Selection
              Text("SELECT YOUR PLAN", style: AppTheme.sectionHeading),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppTheme.pinePrimary),
                  ),
                )
              else if (_packages.isNotEmpty)
                ..._packages.map((pkg) {
                  final isSelected = _selectedPackage == pkg;
                  final badge = _getPackageBadge(pkg);
                  final isAnnual = pkg.packageType == PackageType.annual;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Pressable(
                      onTap: () {
                        setState(() => _selectedPackage = pkg);
                        AnalyticsService().planSelected(planType: pkg.packageType.name);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.pineLight : AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.pinePrimary : (isAnnual ? AppTheme.pineBorder : AppTheme.surfaceBorder),
                            width: isSelected ? 2.0 : (isAnnual ? 1.4 : 1.0),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.pinePrimary.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? AppTheme.pinePrimary : AppTheme.inkMuted,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _getPackageTitle(pkg),
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      if (badge != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.ochreLight,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Text(
                                            badge,
                                            style: AppTheme.tagText.copyWith(
                                              fontSize: 10,
                                              color: AppTheme.ochreAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getPackageSubtitle(pkg),
                                    style: AppTheme.body.copyWith(fontSize: 12, color: AppTheme.inkSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              pkg.storeProduct.priceString,
                              style: AppTheme.amountMonospace.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppTheme.pinePrimary : AppTheme.inkPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
              else ...[
                // Fallback options for testing
                _buildFallbackOption(
                  keyId: 'annual',
                  title: 'Annual Plan',
                  subtitle: 'Save 50% • \$29.99/year · \$2.50/month',
                  price: '\$29.99/yr',
                  badge: 'BEST VALUE • SAVE 50%',
                  isHighlighted: true,
                ),
                _buildFallbackOption(
                  keyId: 'lifetime',
                  title: 'Lifetime Pro',
                  subtitle: 'Pay once, keep forever • Zero recurring fees',
                  price: '\$59.99',
                  badge: 'ONE-TIME PURCHASE',
                ),
                _buildFallbackOption(
                  keyId: 'monthly',
                  title: 'Monthly Plan',
                  subtitle: 'Flexible • Cancel anytime',
                  price: '\$4.99/mo',
                ),
              ],

              const SizedBox(height: 20),

              // Action button
              Pressable(
                onTap: _isLoading ? null : _purchase,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.pinePrimary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.pineDark.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Continue with Selected Plan',
                    style: AppTheme.bodyMedium.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: _isLoading ? null : _restore,
                style: TextButton.styleFrom(foregroundColor: AppTheme.inkMuted),
                child: Text('Restore Purchases', style: AppTheme.tagText.copyWith(color: AppTheme.inkSecondary)),
              ),
              const SizedBox(height: 8),
              Text(
                'Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period in your Google Play / App Store subscription settings. You can manage or cancel anytime with one tap.',
                textAlign: TextAlign.center,
                style: AppTheme.tagText.copyWith(color: AppTheme.inkMuted, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackOption({
    required String keyId,
    required String title,
    required String subtitle,
    required String price,
    String? badge,
    bool isHighlighted = false,
  }) {
    final isSelected = _selectedFallback == keyId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: () {
          setState(() => _selectedFallback = keyId);
          AnalyticsService().planSelected(planType: keyId);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.pineLight : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.pinePrimary : (isHighlighted ? AppTheme.pineBorder : AppTheme.surfaceBorder),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppTheme.pinePrimary : AppTheme.inkMuted,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTheme.bodyMedium.copyWith(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.ochreLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              badge,
                              style: AppTheme.tagText.copyWith(
                                fontSize: 10,
                                color: AppTheme.ochreAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTheme.body.copyWith(fontSize: 12, color: AppTheme.inkSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: AppTheme.amountMonospace.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.pinePrimary : AppTheme.inkPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              color: AppTheme.pineLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.pinePrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.body.copyWith(fontSize: 12, color: AppTheme.inkSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
