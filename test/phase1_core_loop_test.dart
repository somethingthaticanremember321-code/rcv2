import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:incomegen/config/api_config.dart';
import 'package:incomegen/models/transaction.dart';
import 'package:incomegen/services/database_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ahl_phase1_test_');
    Hive.init(tempDir.path);
    db = DatabaseService();
    await db.init(isUnitTest: true);
  });

  tearDown(() async {
    await db.close();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Ahl Phase 1 — Core Loop & Dashboard Verification', () {
    test('1. Default state produces clean zero-summary for current month', () {
      final now = DateTime.now();
      final summary = db.getMonthlySummary(now);

      expect(summary.totalIncome, equals(0.0));
      expect(summary.totalExpense, equals(0.0));
      expect(summary.netPosition, equals(0.0));
      expect(summary.transactionCount, equals(0));
    });

    test('2. Logging expenses and income computes exact Net Position and Member Attribution', () async {
      final now = DateTime.now();
      final household = db.getHousehold();
      final members = db.getMembers();
      final categories = db.getCategories();

      final selfMember = members.firstWhere((m) => m.role == 'self');
      final spouseMember = members.firstWhere((m) => m.role == 'spouse');
      final groceriesCat = categories.firstWhere((c) => c.nameEn == 'Groceries & Household');
      final housingCat = categories.firstWhere((c) => c.nameEn == 'Housing');

      // 1. Log monthly salary inflow (Income: +25,000 QAR)
      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: selfMember.id,
        categoryId: housingCat.id,
        amount: 25000.0,
        type: 'income',
        date: now,
        note: 'راتب شهري',
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Log groceries expense by Self (Expense: -1,500 QAR)
      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: selfMember.id,
        categoryId: groceriesCat.id,
        amount: 1500.0,
        type: 'expense',
        date: now,
        note: 'كارفور قطر',
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Log groceries expense by Spouse (Expense: -2,500 QAR)
      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: spouseMember.id,
        categoryId: groceriesCat.id,
        amount: 2500.0,
        type: 'expense',
        date: now,
        note: 'لولو هايبر ماركت',
        createdAt: now,
        updatedAt: now,
      ));

      // Verify Monthly Summary
      final summary = db.getMonthlySummary(now);
      expect(summary.totalIncome, equals(25000.0));
      expect(summary.totalExpense, equals(4000.0));
      expect(summary.netPosition, equals(21000.0)); // 25,000 - 4,000
      expect(summary.transactionCount, equals(3));

      // Verify Member Spending Breakdown
      final breakdown = db.getMemberSpendingBreakdown(now);
      expect(breakdown[selfMember.id], equals(1500.0));
      expect(breakdown[spouseMember.id], equals(2500.0));

      // Verify spending ratio
      final totalExpense = summary.totalExpense;
      final selfRatio = breakdown[selfMember.id]! / totalExpense;
      final spouseRatio = breakdown[spouseMember.id]! / totalExpense;
      expect(selfRatio, closeTo(0.375, 0.001)); // 37.5%
      expect(spouseRatio, closeTo(0.625, 0.001)); // 62.5%
    });

    test('3. Transactions outside active month are excluded from current month summary', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 15);
      final household = db.getHousehold();
      final member = db.getMembers().first;
      final category = db.getCategories().first;

      // Add transaction in last month
      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: member.id,
        categoryId: category.id,
        amount: 5000.0,
        type: 'expense',
        date: lastMonth,
        createdAt: lastMonth,
        updatedAt: lastMonth,
      ));

      // Current month should still be 0
      final currentSummary = db.getMonthlySummary(now);
      expect(currentSummary.totalExpense, equals(0.0));
      expect(currentSummary.transactionCount, equals(0));

      // Last month summary should be 5000
      final lastMonthSummary = db.getMonthlySummary(lastMonth);
      expect(lastMonthSummary.totalExpense, equals(5000.0));
      expect(lastMonthSummary.netPosition, equals(-5000.0));
      expect(lastMonthSummary.transactionCount, equals(1));
    });

    test('4. Onboarding state and household customization persist reliably', () async {
      // Check initial state
      expect(db.hasSeenOnboarding, isFalse);

      // Simulate Onboarding Step 1 (Language Switch to English)
      final household = db.getHousehold();
      final updatedHousehold = household.copyWith(
        preferredLanguage: 'en',
        name: 'The Al-Mansoor Family',
        currencyCode: 'SAR',
        currencySymbol: 'ر.س',
      );
      await db.updateHousehold(updatedHousehold);

      // Simulate Onboarding Step 2 (Contributors customization)
      final members = db.getMembers();
      final primary = members.firstWhere((m) => m.isPrimary);
      await db.updateMember(primary.copyWith(name: 'Khalid'));

      // Simulate Onboarding Step 4 completion
      await db.setHasSeenOnboarding(true);

      // Verify persistence
      expect(db.hasSeenOnboarding, isTrue);

      final reloadedHousehold = db.getHousehold();
      expect(reloadedHousehold.preferredLanguage, equals('en'));
      expect(reloadedHousehold.name, equals('The Al-Mansoor Family'));
      expect(reloadedHousehold.currencyCode, equals('SAR'));
      expect(reloadedHousehold.currencySymbol, equals('ر.س'));

      final reloadedMember = db.getMemberById(primary.id);
      expect(reloadedMember?.name, equals('Khalid'));
    });

    test('5. Deleting a transaction removes it and recalculates net position immediately', () async {
      final now = DateTime.now();
      final household = db.getHousehold();
      final member = db.getMembers().first;
      final category = db.getCategories().first;

      final txId = const Uuid().v4();
      await db.addTransaction(Transaction(
        id: txId,
        householdId: household.id,
        memberId: member.id,
        categoryId: category.id,
        amount: 300.0,
        type: 'expense',
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      expect(db.getMonthlySummary(now).totalExpense, equals(300.0));

      await db.deleteTransaction(txId);

      final summary = db.getMonthlySummary(now);
      expect(summary.totalExpense, equals(0.0));
      expect(summary.transactionCount, equals(0));
    });

    test('6. ApiConfig holds all expected keys and endpoints from previous builds', () {
      expect(ApiConfig.revenueCatGoogleApiKey, equals('goog_tOgGGRIeVtPOJQSsoyzPnFBdroK'));
      expect(ApiConfig.revenueCatAppleApiKey, equals('appl_YOUR_APPLE_API_KEY'));
      expect(ApiConfig.postHogApiKey, equals('phc_CfnjTMP3ZUUP4gBjC6o7LgULB5AbssASQYxNDEHtnm82'));
      expect(ApiConfig.postHogHost, equals('https://app.posthog.com'));
      expect(ApiConfig.deepSeekApiKey, equals('sk-5aa5c52cd9bc4290bcd39d3ab992f402'));
      expect(ApiConfig.deepSeekBaseUrl, equals('https://api.deepseek.com'));
      expect(ApiConfig.firebaseProjectId, equals('lockin-c01ca'));
      expect(ApiConfig.firebaseApiKey.isNotEmpty, isTrue);
    });
  });
}
