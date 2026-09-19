import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:incomegen/models/household.dart';
import 'package:incomegen/models/member.dart';
import 'package:incomegen/models/category.dart';
import 'package:incomegen/models/category_budget_override.dart';
import 'package:incomegen/models/transaction.dart';
import 'package:incomegen/models/zakat_asset.dart';
import 'package:incomegen/models/zakat_payment.dart';
import 'package:incomegen/services/database_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ahl_phase0_test_');
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

  group('Ahl Phase 0 — Data Layer & Schema Verification', () {
    test('1. First-run seeding creates default household, members, and GCC categories', () {
      final household = db.getHousehold();
      expect(household.name, equals('عائلتنا'));
      expect(household.currencyCode, equals('QAR'));
      expect(household.currencySymbol, equals('ر.ق'));
      expect(household.preferredLanguage, equals('ar'));
      expect(household.nisabStandard, equals('gold_85g'));
      expect(household.zakatAuthorityGuidance, equals('qatar_awqaf'));
      expect(household.cachedGoldPricePerGram, equals(320.0));
      expect(household.schemaVersion, equals(1));

      final members = db.getMembers();
      expect(members.length, equals(2));
      final primary = members.firstWhere((m) => m.isPrimary);
      expect(primary.name, equals('أنا'));
      expect(primary.role, equals('self'));
      expect(primary.colorHex, equals('#0F6E56')); // Deep teal
      expect(primary.schemaVersion, equals(1));

      final spouse = members.firstWhere((m) => !m.isPrimary);
      expect(spouse.role, equals('spouse'));
      expect(spouse.schemaVersion, equals(1));

      final categories = db.getCategories();
      expect(categories.length, equals(8));
      expect(categories.any((c) => c.nameEn == 'Housing' && c.nameAr == 'السكن'), isTrue);
      expect(categories.any((c) => c.nameEn == 'Groceries & Household' && c.nameAr == 'المؤن والمقاضي'), isTrue);
      expect(categories.any((c) => c.nameEn == 'Education' && c.nameAr == 'التعليم'), isTrue);
      expect(categories.any((c) => c.nameEn == 'Domestic Services' && c.nameAr == 'العمالة المنزلية'), isTrue);
      expect(categories.every((c) => c.schemaVersion == 1), isTrue);
    });

    test('2. Member CRUD & attribution works seamlessly', () async {
      final household = db.getHousehold();
      final newMember = Member(
        id: 'member-child-1',
        householdId: household.id,
        name: 'Saad (Son)',
        role: 'dependent',
        colorHex: '#4A90E2',
        isPrimary: false,
        createdAt: DateTime.now(),
      );

      await db.addMember(newMember);
      expect(db.getMembers().length, equals(3));

      final fetched = db.getMemberById('member-child-1');
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Saad (Son)'));
      expect(fetched.schemaVersion, equals(1));

      await db.deleteMember('member-child-1');
      expect(db.getMembers().length, equals(2));
    });

    test('3. Seasonal Category Budget Override (Ramadan / Eid seasonality) takes precedence', () async {
      final household = db.getHousehold();
      final groceriesCat = db.getCategories().firstWhere((c) => c.nameEn == 'Groceries & Household');

      // Baseline is 3,500 QAR
      expect(groceriesCat.baselineMonthlyBudget, equals(3500.0));
      expect(db.getEffectiveCategoryBudget(groceriesCat.id, '2026-01'), equals(3500.0));

      // Ramadan / Eid override for March 2026: 6,000 QAR
      final ramadanOverride = CategoryBudgetOverride(
        id: 'override-ramadan-2026',
        householdId: household.id,
        categoryId: groceriesCat.id,
        yearMonth: '2026-03',
        overrideBudget: 6000.0,
        note: 'Ramadan family hospitality & iftar provisions',
      );
      await db.setCategoryBudgetOverride(ramadanOverride);

      // Verify March 2026 uses 6,000 while other months use baseline 3,500
      expect(db.getEffectiveCategoryBudget(groceriesCat.id, '2026-03'), equals(6000.0));
      expect(db.getEffectiveCategoryBudget(groceriesCat.id, '2026-04'), equals(3500.0));
      expect(ramadanOverride.schemaVersion, equals(1));
    });

    test('4. Transactions with member attribution, monthly net position, and multi-currency hooks', () async {
      final household = db.getHousehold();
      final members = db.getMembers();
      final self = members.firstWhere((m) => m.role == 'self');
      final spouse = members.firstWhere((m) => m.role == 'spouse');
      final housingCat = db.getCategories().firstWhere((c) => c.nameEn == 'Housing');
      final groceriesCat = db.getCategories().firstWhere((c) => c.nameEn == 'Groceries & Household');

      final date = DateTime(2026, 3, 15);

      // Income: Monthly salary
      await db.addTransaction(Transaction(
        id: 'tx-inc-1',
        householdId: household.id,
        memberId: self.id,
        categoryId: housingCat.id,
        amount: 35000.0,
        type: 'income',
        date: date,
        note: 'March salary deposit',
        createdAt: date,
        updatedAt: date,
      ));

      // Expense 1: Rent paid by Self
      await db.addTransaction(Transaction(
        id: 'tx-exp-1',
        householdId: household.id,
        memberId: self.id,
        categoryId: housingCat.id,
        amount: 8000.0,
        type: 'expense',
        date: date,
        note: 'Villa rent',
        createdAt: date,
        updatedAt: date,
      ));

      // Expense 2: Groceries paid by Spouse (with multi-currency hook e.g. online order in USD)
      await db.addTransaction(Transaction(
        id: 'tx-exp-2',
        householdId: household.id,
        memberId: spouse.id,
        categoryId: groceriesCat.id,
        amount: 728.0, // Converted to QAR
        type: 'expense',
        date: date,
        note: 'Specialty organic pantry delivery',
        originalCurrency: 'USD',
        originalAmount: 200.0,
        exchangeRate: 3.64,
        createdAt: date,
        updatedAt: date,
      ));

      // Monthly Summary
      final summary = db.getMonthlySummary(date);
      expect(summary.totalIncome, equals(35000.0));
      expect(summary.totalExpense, equals(8728.0));
      expect(summary.netPosition, equals(26272.0));
      expect(summary.transactionCount, equals(3));

      // Member split breakdown
      final memberSplit = db.getMemberSpendingBreakdown(date);
      expect(memberSplit[self.id], equals(8000.0));
      expect(memberSplit[spouse.id], equals(728.0));
    });

    test('5. Zakat calculations with gold nisab threshold, deductible debts, and contribution tracking', () async {
      final household = db.getHousehold();
      final self = db.getMembers().firstWhere((m) => m.role == 'self');
      final obligationPeriod = '1447 AH';

      // 85g gold * 320 QAR/g = 27,200 QAR nisab threshold
      const expectedNisab = 85.0 * 320.0; // 27,200 QAR

      // Add Asset 1: Liquid savings (100,000 QAR)
      await db.addZakatAsset(ZakatAsset(
        id: 'asset-cash-1',
        householdId: household.id,
        memberId: self.id,
        assetType: 'cash',
        name: 'Islamic Savings Account',
        cashValue: 100000.0,
        hawlStartDate: DateTime(2025, 4, 1),
        updatedAt: DateTime.now(),
      ));

      // Add Asset 2: Gold bullion with short-term deductible debt
      await db.addZakatAsset(ZakatAsset(
        id: 'asset-gold-1',
        householdId: household.id,
        memberId: self.id,
        assetType: 'gold',
        name: '24K Gold Bar (100g)',
        cashValue: 32000.0, // 100g * 320 QAR/g
        weightGrams: 100.0,
        purityKarat: 24,
        deductibleLiabilities: 12000.0, // 12,000 QAR immediate debt owed
        hawlStartDate: DateTime(2025, 4, 1),
        updatedAt: DateTime.now(),
      ));

      // Total Gross: 100,000 + 32,000 = 132,000 QAR
      // Deductible Liabilities: 12,000 QAR
      // Net Zakatable Wealth: 120,000 QAR (above 27,200 nisab)
      // Total Zakat Due (2.5% of 120,000): 3,000 QAR
      var zakatSummary = db.getZakatObligationSummary(obligationPeriod: obligationPeriod);
      expect(zakatSummary.totalGrossAssets, equals(132000.0));
      expect(zakatSummary.totalDeductibleLiabilities, equals(12000.0));
      expect(zakatSummary.netZakatableWealth, equals(120000.0));
      expect(zakatSummary.nisabThreshold, equals(expectedNisab));
      expect(zakatSummary.isNisabMet, isTrue);
      expect(zakatSummary.totalZakatDue, equals(3000.0));
      expect(zakatSummary.totalZakatPaid, equals(0.0));
      expect(zakatSummary.remainingZakatOwed, equals(3000.0));
      expect(zakatSummary.isObligationFulfilled, isFalse);

      // Make a partial Zakat contribution of 1,000 QAR to Qatar Charity
      await db.addZakatPayment(ZakatPayment(
        id: 'pay-zakat-1',
        householdId: household.id,
        memberId: self.id,
        obligationPeriod: obligationPeriod,
        amount: 1000.0,
        paymentDate: DateTime.now(),
        recipient: 'Qatar Charity',
        note: 'First installment for 1447 AH',
      ));

      zakatSummary = db.getZakatObligationSummary(obligationPeriod: obligationPeriod);
      expect(zakatSummary.totalZakatPaid, equals(1000.0));
      expect(zakatSummary.remainingZakatOwed, equals(2000.0));
      expect(zakatSummary.isObligationFulfilled, isFalse);

      // Complete the remaining 2,000 QAR contribution
      await db.addZakatPayment(ZakatPayment(
        id: 'pay-zakat-2',
        householdId: household.id,
        memberId: self.id,
        obligationPeriod: obligationPeriod,
        amount: 2000.0,
        paymentDate: DateTime.now(),
        recipient: 'Qatar Red Crescent',
        note: 'Final fulfillment for 1447 AH',
      ));

      zakatSummary = db.getZakatObligationSummary(obligationPeriod: obligationPeriod);
      expect(zakatSummary.totalZakatPaid, equals(3000.0));
      expect(zakatSummary.remainingZakatOwed, equals(0.0));
      expect(zakatSummary.isObligationFulfilled, isTrue);
    });

    test('6. Universal schemaVersion discipline holds across all models', () {
      final now = DateTime.now();
      final h = Household(id: '1', name: 'H', createdAt: now, updatedAt: now);
      final m = Member(id: '2', householdId: '1', name: 'M', createdAt: now);
      final c = Category(id: '3', householdId: '1', nameEn: 'C', nameAr: 'ت');
      final o = CategoryBudgetOverride(id: '4', householdId: '1', categoryId: '3', yearMonth: '2026-03', overrideBudget: 100);
      final t = Transaction(id: '5', householdId: '1', memberId: '2', categoryId: '3', amount: 50, type: 'expense', date: now, createdAt: now, updatedAt: now);
      final a = ZakatAsset(id: '6', householdId: '1', assetType: 'cash', name: 'A', cashValue: 1000, updatedAt: now);
      final p = ZakatPayment(id: '7', householdId: '1', obligationPeriod: '1447 AH', amount: 25, paymentDate: now);

      expect(h.schemaVersion, equals(1));
      expect(m.schemaVersion, equals(1));
      expect(c.schemaVersion, equals(1));
      expect(o.schemaVersion, equals(1));
      expect(t.schemaVersion, equals(1));
      expect(a.schemaVersion, equals(1));
      expect(p.schemaVersion, equals(1));
    });
  });
}
