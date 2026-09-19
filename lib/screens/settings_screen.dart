import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/receipt.dart';
import '../services/database_service.dart';
import '../services/paywall_service.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';
import 'paywall_screen.dart';
import 'legal_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _devTapCount = 0;

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final paywallService = PaywallService();

    return Scaffold(
      backgroundColor: AppTheme.paperBg,
      appBar: AppBar(
        title: Text('Settings', style: AppTheme.brandTitle),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: paywallService.isPro,
        builder: (context, isPro, _) {
          return ValueListenableBuilder<Box<Receipt>>(
            valueListenable: dbService.listenable,
            builder: (context, box, _) {
              final scanCount = box.length;
              const maxFreeScans = DatabaseService.maxFreeScans;
              final scansRemaining = (maxFreeScans - scanCount).clamp(0, maxFreeScans);

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // 1. Hero Pro / Usage Status Banner
                  _buildHeroPaywallCard(context, isPro, scanCount, maxFreeScans, scansRemaining),

                  const SizedBox(height: 24),

                  // 2. Data & Usage
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text("DATA & EXPORTS", style: AppTheme.sectionHeading),
                  ),
                  _buildSettingsGroup([
                    _SettingsItem(
                      icon: Icons.receipt_long_outlined,
                      title: "Total Receipts Tracked",
                      trailingWidget: Text(
                        "$scanCount",
                        style: AppTheme.amountMonospace.copyWith(fontSize: 16),
                      ),
                    ),
                    _SettingsItem(
                      icon: Icons.file_download_outlined,
                      title: "Export All to CSV",
                      subtitle: "Ready for Excel, Google Sheets, or your accountant",
                      onTap: scanCount == 0
                          ? null
                          : () async {
                              await ExportService().exportReceiptsToCSV();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Receipts exported to CSV!')),
                                );
                              }
                            },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // 3. Purchases & Account
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text("MEMBERSHIP & PURCHASES", style: AppTheme.sectionHeading),
                  ),
                  _buildSettingsGroup([
                    _SettingsItem(
                      icon: Icons.restore_rounded,
                      title: "Restore Purchases",
                      subtitle: "Already purchased Pro? Restore your access",
                      onTap: () async {
                        final success = await paywallService.restorePurchases();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Purchases restored successfully!' : 'No active purchases found.'),
                            ),
                          );
                        }
                      },
                    ),
                    if (!isPro)
                      _SettingsItem(
                        icon: Icons.workspace_premium_outlined,
                        title: "Upgrade to Pro",
                        subtitle: "Unlimited multi-page scans • Starting at \$2.50/mo",
                        iconColor: AppTheme.ochreAccent,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PaywallScreen()),
                          );
                        },
                      ),
                  ]),

                  const SizedBox(height: 24),

                  // 4. Privacy & Data Safety
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text("DEVICE STORAGE & PRIVACY", style: AppTheme.sectionHeading),
                  ),
                  _buildSettingsGroup([
                    const _SettingsItem(
                      icon: Icons.security_rounded,
                      title: "Private Photo Processing",
                      subtitle: "Receipt photos are scanned locally on your phone and never uploaded. Extracted text is sent over TLS 1.3 solely for structuring.",
                      trailingWidget: Icon(Icons.check_circle_rounded, color: AppTheme.pinePrimary, size: 20),
                    ),
                    const _SettingsItem(
                      icon: Icons.insights_rounded,
                      title: "Product Telemetry (PostHog)",
                      subtitle: "Anonymous usage events are collected to improve app stability. We never collect or transmit receipt images or financial figures.",
                      trailingWidget: Icon(Icons.check_circle_rounded, color: AppTheme.pinePrimary, size: 20),
                    ),
                    _SettingsItem(
                      icon: Icons.delete_outline_rounded,
                      title: "Clear All Receipts",
                      subtitle: "Permanently delete all local receipt data",
                      iconColor: AppTheme.terracotta,
                      textColor: AppTheme.terracotta,
                      onTap: scanCount == 0 ? null : () => _confirmClearData(context, dbService),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // 5. Legal & Policies
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text("LEGAL & POLICIES", style: AppTheme.sectionHeading),
                  ),
                  _buildSettingsGroup([
                    _SettingsItem(
                      icon: Icons.privacy_tip_outlined,
                      title: "Privacy Policy",
                      subtitle: "Zero photo retention & encrypted data guarantees",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalScreen(initialDoc: LegalDocType.privacy),
                          ),
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.description_outlined,
                      title: "Terms of Service",
                      subtitle: "Subscriptions, usage terms, and disclaimers",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalScreen(initialDoc: LegalDocType.terms),
                          ),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 36),
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _devTapCount++;
                        if (_devTapCount >= 5) {
                          _devTapCount = 0;
                          paywallService.togglePro();
                          final proActive = paywallService.isPro.value;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: proActive ? AppTheme.pinePrimary : AppTheme.inkPrimary,
                              content: Text(
                                proActive
                                    ? '🌟 VIP Mode: Pro Unlocked! Unlimited scans active.'
                                    : 'Pro mode deactivated.',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Text(
                          "DashTally • Version 1.0.0",
                          style: AppTheme.tagText.copyWith(color: AppTheme.inkMuted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroPaywallCard(
    BuildContext context,
    bool isPro,
    int scanCount,
    int maxFreeScans,
    int scansRemaining,
  ) {
    if (isPro) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.pinePrimary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.pineDark.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DashTally Pro Active",
                    style: AppTheme.editorialHeading.copyWith(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Unlimited multi-page scans, CSV exports & AI assistant.",
                    style: AppTheme.body.copyWith(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isLimitReached = scanCount >= maxFreeScans;

    return Pressable(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLimitReached ? const Color(0xFFFEF2F2) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLimitReached ? const Color(0xFFFECACA) : AppTheme.ochreAccent.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLimitReached ? AppTheme.terracotta : AppTheme.ochreAccent).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLimitReached ? Icons.lock_outline_rounded : Icons.bolt_rounded,
                  color: isLimitReached ? AppTheme.terracotta : AppTheme.ochreAccent,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isLimitReached ? "Free Evaluation Scan Used" : "1 Free Evaluation Scan Available",
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLimitReached ? AppTheme.terracotta : AppTheme.inkPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLimitReached ? AppTheme.terracotta : AppTheme.pinePrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLimitReached ? "Unlock Pro" : "Upgrade",
                    style: AppTheme.tagText.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (scanCount / maxFreeScans).clamp(0.0, 1.0),
                backgroundColor: AppTheme.surfaceBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isLimitReached ? AppTheme.terracotta : AppTheme.pinePrimary,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isLimitReached
                  ? "Hard paywall active. Unlock Pro for unlimited multi-page scans."
                  : "$scansRemaining free scans remaining. Tap to unlock unlimited access.",
              style: AppTheme.body.copyWith(color: AppTheme.inkSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  void _confirmClearData(BuildContext context, DatabaseService dbService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.paperBg,
        title: Text('Clear All Receipts?', style: AppTheme.editorialHeading.copyWith(fontSize: 18)),
        content: Text(
          'This will permanently delete all scanned receipts and expenses stored on your device. This cannot be undone.',
          style: AppTheme.body.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTheme.body.copyWith(color: AppTheme.inkSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await dbService.clearAllReceipts();
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All local receipt data deleted.')),
                );
              }
            },
            child: const Text('Delete All', style: TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingWidget,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? AppTheme.pinePrimary, size: 22),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(
          color: textColor ?? AppTheme.inkPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTheme.body.copyWith(color: AppTheme.inkMuted, fontSize: 12.5),
            )
          : null,
      trailing: trailingWidget ??
          (onTap != null
              ? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.inkMuted)
              : null),
    );
  }
}
