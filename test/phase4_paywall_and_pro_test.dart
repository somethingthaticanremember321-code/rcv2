import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:incomegen/models/transaction.dart';
import 'package:incomegen/models/zakat_asset.dart';
import 'package:incomegen/models/zakat_payment.dart';
import 'package:incomegen/screens/paywall_screen.dart';
import 'package:incomegen/services/analytics_service.dart';
import 'package:incomegen/services/database_service.dart';
import 'package:incomegen/services/export_service.dart';
import 'package:incomegen/services/paywall_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;
  final paywall = PaywallService();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ahl_phase4_test_');
    Hive.init(tempDir.path);
    db = DatabaseService();
    await db.init(isUnitTest: true);
    paywall.setProForTesting(false);
  });

  tearDown(() async {
    await db.close();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    paywall.setProForTesting(false);
  });

  group('Ahl Phase 4 — Paywall & Pro Entitlements Engine Verification', () {
    test('1. PaywallService default state, togglePro, and setProForTesting', () {
      paywall.setProForTesting(false);
      expect(paywall.isProUser, isFalse);
      expect(paywall.isPro.value, isFalse);

      paywall.setProForTesting(true);
      expect(paywall.isProUser, isTrue);
      expect(paywall.isPro.value, isTrue);

      paywall.togglePro();
      expect(paywall.isProUser, isFalse);

      paywall.togglePro();
      expect(paywall.isProUser, isTrue);
    });

    test('2. Free Tier entitlement limits enforcement', () {
      paywall.setProForTesting(false);

      // Member limit: 2 members max for free tier
      expect(paywall.canAddMember(0), isTrue);
      expect(paywall.canAddMember(1), isTrue);
      expect(paywall.canAddMember(2), isFalse);
      expect(paywall.canAddMember(5), isFalse);

      // Seasonal Override limit: 1 override max for free tier
      expect(paywall.canAddSeasonalOverride(0), isTrue);
      expect(paywall.canAddSeasonalOverride(1), isFalse);
      expect(paywall.canAddSeasonalOverride(3), isFalse);

      // Zakat Asset limit: 3 assets max for free tier
      expect(paywall.canAddZakatAsset(0), isTrue);
      expect(paywall.canAddZakatAsset(1), isTrue);
      expect(paywall.canAddZakatAsset(2), isTrue);
      expect(paywall.canAddZakatAsset(3), isFalse);
      expect(paywall.canAddZakatAsset(7), isFalse);

      // Export data: Pro only
      expect(paywall.canExportData, isFalse);
    });

    test('3. Ahl Pro tier completely unlocks all restrictions', () {
      paywall.setProForTesting(true);

      // Unlimited members
      expect(paywall.canAddMember(0), isTrue);
      expect(paywall.canAddMember(2), isTrue);
      expect(paywall.canAddMember(10), isTrue);

      // Unlimited concurrent seasonal overrides
      expect(paywall.canAddSeasonalOverride(0), isTrue);
      expect(paywall.canAddSeasonalOverride(1), isTrue);
      expect(paywall.canAddSeasonalOverride(5), isTrue);

      // Unlimited zakatable assets
      expect(paywall.canAddZakatAsset(0), isTrue);
      expect(paywall.canAddZakatAsset(3), isTrue);
      expect(paywall.canAddZakatAsset(25), isTrue);

      // Export data allowed
      expect(paywall.canExportData, isTrue);
    });

    test('4. Fallback plans return Annual and Monthly tiers with pricing', () async {
      final plans = await paywall.getAvailablePlans(currencySymbol: 'ر.ق');
      expect(plans.length, greaterThanOrEqualTo(2));

      final annualPlan = plans.firstWhere((p) => p.id.contains('annual'));
      expect(annualPlan.hasTrial, isTrue);
      expect(annualPlan.savingsBadgeAr, contains('٤٥٪'));
      expect(annualPlan.savingsBadgeEn, contains('45%'));
      expect(annualPlan.priceDisplayAr, contains('ر.ق'));

      final monthlyPlan = plans.firstWhere((p) => p.id.contains('monthly'));
      expect(monthlyPlan.hasTrial, isFalse);
      expect(monthlyPlan.priceDisplayAr, contains('ر.ق'));
    });

    test('5. ExportService generates UTF-8 BOM CSV for transactions', () {
      final household = db.getHousehold().copyWith(preferredLanguage: 'en');
      final categories = {for (var c in db.getCategories()) c.id: c};
      final members = {for (var m in db.getMembers()) m.id: m};

      final tx = Transaction(
        id: 'tx-export-1',
        householdId: household.id,
        memberId: members.keys.first,
        categoryId: categories.keys.first,
        type: 'expense',
        amount: 450.75,
        date: DateTime(2026, 3, 15, 14, 30),
        note: 'Al Meera groceries "family feast"',
        createdAt: DateTime(2026, 3, 15, 14, 30),
        updatedAt: DateTime(2026, 3, 15, 14, 30),
      );

      final csv = ExportService().generateTransactionsCsv(
        household: household,
        transactions: [tx],
        categories: categories,
        members: members,
      );

      // Starts with UTF-8 BOM for Excel Arabic/Unicode compatibility
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('Date,Type,Amount,Currency,Category,Contributor,Role,Notes'));
      expect(csv, contains('450.75'));
      expect(csv, contains('QAR'));
      expect(csv, contains('Al Meera groceries ""family feast""'));
    });

    test('6. ExportService generates comprehensive Arabic Shariah Zakat audit report', () {
      final household = db.getHousehold().copyWith(
        preferredLanguage: 'ar',
        currencySymbol: 'ر.ق',
      );

      final summary = ZakatObligationSummary(
        nisabStandard: 'gold',
        nisabThreshold: 27200.0,
        totalGrossAssets: 120000.0,
        totalDeductibleLiabilities: 15000.0,
        netZakatableWealth: 105000.0,
        isNisabMet: true,
        totalZakatDue: 2625.0,
        totalZakatPaid: 1000.0,
        remainingZakatOwed: 1625.0,
        isObligationFulfilled: false,
        zakatAuthorityGuidance: 'Awqaf',
      );

      final asset = ZakatAsset(
        id: 'ast-1',
        householdId: household.id,
        name: 'ذهب عيار ٢١',
        assetType: 'gold',
        purityKarat: 21,
        weightGrams: 50.0,
        cashValue: 14000.0,
        deductibleLiabilities: 0.0,
        hawlStartDate: DateTime(2025, 4, 1),
        updatedAt: DateTime.now(),
      );

      final payment = ZakatPayment(
        id: 'pay-1',
        householdId: household.id,
        obligationPeriod: '1447 AH',
        amount: 1000.0,
        recipient: 'قطر الخيرية',
        paymentDate: DateTime(2026, 3, 1),
        note: 'دفعة أولى من زكاة المال',
      );

      final csv = ExportService().generateZakatReportCsv(
        household: household,
        summary: summary,
        assets: [asset],
        payments: [payment],
        obligationPeriod: '1447 AH',
      );

      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('=== تقرير حساب الزكاة الشرعي — تطبيق أهل ==='));
      expect(csv, contains('1447 AH'));
      expect(csv, contains('27200.00'));
      expect(csv, contains('105000.00'));
      expect(csv, contains('2625.00'));
      expect(csv, contains('قطر الخيرية'));
      expect(csv, contains('ذهب عيار ٢١'));
    });

    testWidgets('7. PaywallScreen displays Arabic UI, value matrix, and plan options',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PaywallScreen(trigger: 'test_phase4'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header & Branding
      expect(find.text('أهل برو'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);

      // Check for value propositions
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.balance_rounded), findsOneWidget);
      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Check plan cards rendered
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      // Check restore button rendered
      expect(find.byType(TextButton), findsWidgets);
    });

    test('8. Analytics service logs paywall events correctly', () {
      final analytics = AnalyticsService();
      // Should execute without throwing any exceptions
      expect(() => analytics.paywallImpression(trigger: 'test_trigger'), returnsNormally);
      expect(() => analytics.paywallConverted(planId: 'annual', isPro: true), returnsNormally);
      expect(() => analytics.paywallRestored(isPro: true), returnsNormally);
    });
  });
}
