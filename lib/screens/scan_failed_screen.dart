import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';
import 'verification_screen.dart';

class ScanFailedScreen extends StatelessWidget {
  final String imagePath;
  final String reason;

  const ScanFailedScreen({super.key, required this.imagePath, required this.reason});

  String _getFriendlyReason() {
    switch (reason) {
      case 'no_text_found':
        return 'No readable text was detected. The photo may be too blurry, dark, or reflective.';
      case 'server_error':
        return 'Unable to reach the parsing service. Check your internet connection and try again.';
      case 'parse_error':
        return 'The receipt text was partially detected but could not be structured.';
      default:
        return 'We could not cleanly extract fields from this receipt.';
    }
  }

  void _enterManually(BuildContext context) {
    final emptyReceipt = Receipt(
      localImagePath: imagePath,
      syncStatus: 'pending',
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => VerificationScreen(receipt: emptyReceipt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final remaining = db.remainingFreeScans;

    AnalyticsService().scanFailed(
      reason: reason,
      attemptNumber: db.getReceiptCount() + 1,
    );

    return Scaffold(
      backgroundColor: AppTheme.paperBg,
      appBar: AppBar(
        title: Text('Scan Unsuccessful', style: AppTheme.brandTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.terracottaLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  size: 48,
                  color: AppTheme.terracotta,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Could Not Read Receipt',
                style: AppTheme.editorialHeading.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _getFriendlyReason(),
                style: AppTheme.body.copyWith(color: AppTheme.inkSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Reassurance badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.ochreLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: AppTheme.ochreAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Unsaved scan — your $remaining free scans remain safe',
                      style: AppTheme.tagText.copyWith(color: AppTheme.ochreAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Retake photo button
              Pressable(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.pinePrimary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.pineDark.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Retake Photo',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Enter manually button
              Pressable(
                onTap: () => _enterManually(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Enter Manually with Photo',
                    style: AppTheme.bodyMedium.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Discard', style: AppTheme.body.copyWith(color: AppTheme.inkMuted, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
