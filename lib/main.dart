import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/database_service.dart';
import 'services/ai_scanner_service.dart';
import 'services/export_service.dart';
import 'services/paywall_service.dart';
import 'services/analytics_service.dart';
import 'models/receipt.dart';
import 'screens/onboarding_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/scan_failed_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/assistant_screen.dart';
import 'screens/camera_flow_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Init Firebase Core
  await Firebase.initializeApp();

  final dbService = DatabaseService();
  await dbService.init();
  await PaywallService().init();
  
  runApp(MyApp(showOnboarding: !dbService.hasSeenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DashTally',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: showOnboarding ? const OnboardingScreen() : const MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AiScannerService _scannerService = AiScannerService();
  bool _isProcessing = false;
  int _currentIndex = 0;

  Future<bool> _ensureCanAddReceipt() async {
    // Hard paywall check: strictly after 1 scan
    if (_dbService.getReceiptCount() >= DatabaseService.maxFreeScans && !PaywallService().isPro.value) {
      AnalyticsService().paywallImpression(
        trigger: 'hard_gate_1_scan',
        attemptsUsed: _dbService.getReceiptCount(),
        savedReceiptCount: _dbService.getReceiptCount(),
      );
      
      final purchased = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      if (purchased != true && !PaywallService().isPro.value) {
        return false;
      }
      return true;
    }
    return true;
  }

  void _showAddOptions() async {
    final canProceed = await _ensureCanAddReceipt();
    if (!canProceed || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.paperBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Add Receipt', style: AppTheme.editorialHeading.copyWith(fontSize: 18)),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.pinePrimary),
                title: Text('Camera Scan (Multi-page)', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('Great for long receipts across multiple snaps', style: AppTheme.body.copyWith(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _processImages(fromCamera: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.pinePrimary),
                title: Text('Import from Gallery', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('For digital receipts or screenshots', style: AppTheme.body.copyWith(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _processImages(fromCamera: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_document, color: AppTheme.pinePrimary),
                title: Text('Manual Entry', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('Quickly type in numbers yourself', style: AppTheme.body.copyWith(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
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
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processImages({required bool fromCamera}) async {
    final canProceed = await _ensureCanAddReceipt();
    if (!canProceed || !mounted) return;

    List<String> imagePaths = [];

    if (fromCamera) {
      final List<XFile>? images = await Navigator.of(context).push<List<XFile>>(
        MaterialPageRoute(builder: (_) => const CameraFlowScreen()),
      );
      if (images == null || images.isEmpty) return;
      imagePaths = images.map((f) => f.path).toList();
    } else {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      imagePaths = [image.path];
    }

    final attemptNum = _dbService.getReceiptCount() + 1;
    AnalyticsService().scanAttemptStarted(
      source: fromCamera ? 'camera' : 'gallery',
      attemptNumber: attemptNum,
    );

    setState(() {
      _isProcessing = true;
    });

    final stopwatch = Stopwatch()..start();
    final result = await _scannerService.parseReceipt(imagePaths);
    stopwatch.stop();

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });

    if (result is ScanSuccess) {
      int fieldsFilled = 0;
      if (result.receipt.vendorName != null) fieldsFilled++;
      if (result.receipt.totalAmount != null) fieldsFilled++;
      if (result.receipt.date != null) fieldsFilled++;
      if (result.receipt.category != null) fieldsFilled++;

      AnalyticsService().scanCompleted(
        success: true,
        durationMs: stopwatch.elapsedMilliseconds,
        fieldsFilled: fieldsFilled,
      );
      
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VerificationScreen(receipt: result.receipt)),
      );
    } else if (result is ScanFailure) {
      AnalyticsService().scanCompleted(
        success: false,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanFailedScreen(
            imagePath: imagePaths.first,
            reason: result.reason,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paperBg,
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.only(left: 12),
          alignment: Alignment.center,
          child: IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.inkPrimary, size: 22),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ),
        title: Text(
          _currentIndex == 0 ? 'DashTally' : 'AI Assistant',
          style: AppTheme.brandTitle,
        ),
        actions: [
          if (_currentIndex == 0)
            ValueListenableBuilder<Box<Receipt>>(
              valueListenable: _dbService.listenable,
              builder: (context, box, _) {
                if (box.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.pinePrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppTheme.pineBorder),
                      ),
                    ),
                    onPressed: () async {
                      await ExportService().exportReceiptsToCSV();
                      AnalyticsService().csvExported(receiptCount: box.length);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipts exported to CSV!')),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      'Export CSV',
                      style: AppTheme.tagText.copyWith(color: AppTheme.pinePrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              DashboardScreen(onAddReceipt: _showAddOptions),
              const AssistantScreen(),
            ],
          ),
          if (_isProcessing)
            Container(
              color: AppTheme.paperBg.withValues(alpha: 0.92),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.pinePrimary)),
                    const SizedBox(height: 20),
                    Text(
                      "Analyzing receipt ledger...",
                      style: AppTheme.editorialHeading.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _showAddOptions,
        backgroundColor: AppTheme.pinePrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_a_photo_outlined, size: 20),
        label: Text(
          'Scan Receipt',
          style: AppTheme.bodyMedium.copyWith(color: Colors.white, letterSpacing: 0.2, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.paperBg,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          selectedItemColor: AppTheme.pinePrimary,
          unselectedItemColor: AppTheme.inkMuted,
          backgroundColor: AppTheme.paperBg,
          elevation: 0,
          selectedLabelStyle: AppTheme.tagText.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTheme.tagText,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome_rounded),
              label: 'AI Assistant',
            ),
          ],
        ),
      ),
    );
  }
}
