import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum LegalDocType { privacy, terms }

class LegalScreen extends StatefulWidget {
  final LegalDocType initialDoc;

  const LegalScreen({super.key, this.initialDoc = LegalDocType.privacy});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late LegalDocType _currentDoc;

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.initialDoc;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paperBg,
      appBar: AppBar(
        title: Text(
          _currentDoc == LegalDocType.privacy ? 'Privacy Policy' : 'Terms of Service',
          style: AppTheme.brandTitle,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentDoc = LegalDocType.privacy),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _currentDoc == LegalDocType.privacy
                            ? AppTheme.pinePrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Privacy Policy',
                        style: AppTheme.tagText.copyWith(
                          color: _currentDoc == LegalDocType.privacy
                              ? Colors.white
                              : AppTheme.inkSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentDoc = LegalDocType.terms),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _currentDoc == LegalDocType.terms
                            ? AppTheme.pinePrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Terms of Service',
                        style: AppTheme.tagText.copyWith(
                          color: _currentDoc == LegalDocType.terms
                              ? Colors.white
                              : AppTheme.inkSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: _currentDoc == LegalDocType.privacy
            ? _buildPrivacyContent()
            : _buildTermsContent(),
      ),
    );
  }

  Widget _buildPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDocHeader(
          title: 'Privacy Policy',
          lastUpdated: 'September 16, 2026',
          summary:
              'DashTally is built on a private-by-design architecture. Your receipt photos are processed locally on your phone and never uploaded or stored in the cloud.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          number: '1',
          title: 'Information We Do NOT Collect',
          body:
              '• Receipt Photos: When you photograph or import a receipt, on-device optical character recognition (OCR) extracts text locally on your device. Receipt image files are saved strictly in your phone\'s local sandbox storage. We never upload, store, or view your original receipt photos on external servers.\n\n• Banking Credentials: We never request, access, or store your bank accounts, credit card numbers, or financial institution logins.',
        ),
        _buildSection(
          number: '2',
          title: 'Text Structuring & AI Processing',
          body:
              'To organize your expenses into structured fields (merchant name, transaction date, tax amount, and total):\n\n• Extracted text lines are transmitted over an encrypted connection (TLS 1.3) solely for field parsing.\n• Neither DashTally nor third-party AI structuring APIs store, log, or use your receipt text to train artificial intelligence models.\n• Once structured data is returned to your device, it is saved exclusively into your local on-device database.',
        ),
        _buildSection(
          number: '3',
          title: 'Product Telemetry & Analytics',
          body:
              'We use PostHog to collect minimal, anonymized application telemetry to ensure app reliability and measure conversion funnels (e.g., app launches, scan completion events, paywall impressions, crash reports).\n\nWe NEVER transmit receipt images, merchant names, line items, or financial amounts to analytics providers. All analytics telemetry is strictly anonymized and aggregated.',
        ),
        _buildSection(
          number: '4',
          title: 'Purchases & Payment Processing',
          body:
              'All in-app purchases, subscriptions, and lifetime licenses are processed directly through the Apple App Store (Apple In-App Purchases) or Google Play Store (Google Play Billing). DashTally does not process or store credit card details. Transaction verification and entitlement tracking are securely managed via RevenueCat using anonymous user identifiers.',
        ),
        _buildSection(
          number: '5',
          title: 'Your Data Rights & Deletion',
          body:
              'You retain 100% ownership of your financial records:\n\n• Export Anytime: You can export your entire ledger to a clean CSV file at any time.\n• Complete Deletion: You can permanently delete individual receipts or purge your entire local ledger at any time in Settings ("Clear All Receipts"). Because records are stored locally, clearing your data permanently erases it from your device.',
        ),
        _buildSection(
          number: '6',
          title: 'Contact Us',
          body:
              'If you have questions regarding this Privacy Policy, please contact our team at:\nsupport@dashtally.com',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDocHeader(
          title: 'Terms of Service',
          lastUpdated: 'September 16, 2026',
          summary:
              'Please read these Terms of Service carefully before using DashTally. By using the app, you agree to these terms.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          number: '1',
          title: 'Service Description',
          body:
              'DashTally is an expense organization and receipt utility designed to help trade contractors, field pros, and small business owners capture and export expense records. DashTally does not provide certified financial, tax, or legal advice. You are solely responsible for reviewing and verifying all extracted figures prior to filing taxes or submitting expense reports.',
        ),
        _buildSection(
          number: '2',
          title: 'Free Trial & Subscription Tiers',
          body:
              '• Free Evaluation Scan: New users receive 1 free receipt scan to evaluate core optical character recognition and export capabilities on crumpled receipts.\n\n• Annual & Monthly Subscriptions: Provide unlimited receipt scans and exports during an active subscription period. Subscriptions automatically renew unless cancelled at least 24 hours prior to the end of the current billing cycle.\n\n• Lifetime Pro: Provides perpetual access to unlimited receipt tracking, ledger management, and CSV exports under our fair use policy without recurring subscription fees.',
        ),
        _buildSection(
          number: '3',
          title: 'Billing, Cancellation & Refunds',
          body:
              '• Payment will be charged to your Google Play or Apple ID account upon purchase confirmation.\n• You can manage or cancel your subscription at any time in your device\'s app store account settings.\n• Refund requests are handled exclusively by Apple or Google in accordance with their respective app store refund policies.',
        ),
        _buildSection(
          number: '4',
          title: 'User Responsibilities',
          body:
              'You agree not to use DashTally for any unlawful purpose, attempt to reverse engineer the application, or exploit automated network interfaces. You are responsible for maintaining backups of your exported CSV records and receipt images.',
        ),
        _buildSection(
          number: '5',
          title: 'Disclaimer of Warranties & Limitation of Liability',
          body:
              'DashTally is provided on an "as-is" and "as-available" basis without warranties of any kind. While on-device OCR and AI structuring strive for high accuracy, errors may occur due to damaged, folded, or low-contrast paper receipts. DashTally and its developers shall not be liable for any tax penalties, accounting discrepancies, or lost profits arising from the use of the app.',
        ),
        _buildSection(
          number: '6',
          title: 'Changes to Terms',
          body:
              'We reserve the right to modify these terms at any time. Continued use of DashTally following updates constitutes acceptance of the revised Terms of Service.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDocHeader({
    required String title,
    required String lastUpdated,
    required String summary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.editorialHeading.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            'Last updated: $lastUpdated',
            style: AppTheme.tagText.copyWith(color: AppTheme.inkMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: AppTheme.body.copyWith(
              color: AppTheme.inkPrimary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppTheme.pineLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: AppTheme.tagText.copyWith(
                    color: AppTheme.pinePrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              body,
              style: AppTheme.body.copyWith(
                color: AppTheme.inkSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
