import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:incomegen/models/zakat_asset.dart';
import 'package:incomegen/models/zakat_payment.dart';
import 'package:incomegen/services/database_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ahl_phase3_test_');
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

  group('Ahl Phase 3 — Zakat Tracker & Shariah Engine Verification', () {
    test('1. Nisab calculation defaults to 85g gold and reflects spot price updates', () async {
      final household = db.getHousehold();
      expect(household.nisabStandard, equals('gold_85g'));
      expect(household.cachedGoldPricePerGram, equals(320.0));

      final summary = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summary.nisabThreshold, equals(85.0 * 320.0)); // 27,200 QAR

      // Update spot price to 340.0 QAR
      final updated = household.copyWith(cachedGoldPricePerGram: 340.0);
      await db.updateHousehold(updated);

      final reloadedSummary = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(reloadedSummary.nisabThreshold, equals(85.0 * 340.0)); // 28,900 QAR
    });

    test('2. Wealth below Nisab produces 0.0 Zakat obligation', () async {
      final household = db.getHousehold();
      final now = DateTime.now();

      // Add 20,000 QAR cash (below 27,200 Nisab)
      await db.addZakatAsset(ZakatAsset(
        id: const Uuid().v4(),
        householdId: household.id,
        assetType: 'cash',
        name: 'حساب توفير',
        cashValue: 20000.0,
        updatedAt: now,
      ));

      final summary = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summary.isNisabMet, isFalse);
      expect(summary.totalZakatDue, equals(0.0));
      expect(summary.remainingZakatOwed, equals(0.0));
    });

    test('3. Wealth exceeding Nisab incurs exact 2.5% Shariah obligation', () async {
      final household = db.getHousehold();
      final now = DateTime.now();

      // Add 120,000 QAR cash
      await db.addZakatAsset(ZakatAsset(
        id: const Uuid().v4(),
        householdId: household.id,
        assetType: 'cash',
        name: 'حساب جاري واستثماري',
        cashValue: 120000.0,
        updatedAt: now,
      ));

      final summary = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summary.isNisabMet, isTrue);
      expect(summary.netZakatableWealth, equals(120000.0));
      expect(summary.totalZakatDue, equals(120000.0 * 0.025)); // 3,000.0 QAR
      expect(summary.remainingZakatOwed, equals(3000.0));
      expect(summary.isObligationFulfilled, isFalse);
    });

    test('4. Deductible short-term liabilities offset gross assets before Nisab check', () async {
      final household = db.getHousehold();
      final now = DateTime.now();

      // 40,000 QAR asset with 20,000 QAR deductible debt -> Net = 20,000 QAR
      await db.addZakatAsset(ZakatAsset(
        id: const Uuid().v4(),
        householdId: household.id,
        assetType: 'trade_goods',
        name: 'بضاعة متجر',
        cashValue: 40000.0,
        deductibleLiabilities: 20000.0,
        updatedAt: now,
      ));

      // Net 20,000 < Nisab 27,200 -> No zakat
      final summaryBelow = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summaryBelow.netZakatableWealth, equals(20000.0));
      expect(summaryBelow.isNisabMet, isFalse);
      expect(summaryBelow.totalZakatDue, equals(0.0));

      // Now add 50,000 QAR cash -> Net = 70,000 QAR -> >= Nisab -> Zakat = 70,000 * 0.025 = 1,750 QAR
      await db.addZakatAsset(ZakatAsset(
        id: const Uuid().v4(),
        householdId: household.id,
        assetType: 'cash',
        name: 'سيولة نقدية',
        cashValue: 50000.0,
        updatedAt: now,
      ));

      final summaryAbove = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summaryAbove.totalGrossAssets, equals(90000.0));
      expect(summaryAbove.totalDeductibleLiabilities, equals(20000.0));
      expect(summaryAbove.netZakatableWealth, equals(70000.0));
      expect(summaryAbove.isNisabMet, isTrue);
      expect(summaryAbove.totalZakatDue, equals(1750.0));
    });

    test('5. Gold weight and karat valuation formula matches fine gold equivalent', () {
      const goldSpotPrice = 320.0;
      const weightGrams = 100.0;
      const karat = 21;

      // 100g of 21K gold = 100 * (21/24) = 87.5g pure 24K gold
      final fineWeight = weightGrams * (karat / 24.0);
      expect(fineWeight, equals(87.5));

      final marketValue = fineWeight * goldSpotPrice;
      expect(marketValue, equals(28000.0));

      // 28,000 QAR >= 27,200 QAR Nisab threshold
      expect(marketValue >= (85.0 * goldSpotPrice), isTrue);

      final zakatDue = marketValue * 0.025;
      expect(zakatDue, equals(700.0));
    });

    test('6. Zakat payments reduce remaining owed and fulfill obligation when paid in full', () async {
      final household = db.getHousehold();
      final now = DateTime.now();

      // 200,000 QAR -> Zakat due = 5,000 QAR
      await db.addZakatAsset(ZakatAsset(
        id: const Uuid().v4(),
        householdId: household.id,
        assetType: 'investments',
        name: 'محفظة استثمارية',
        cashValue: 200000.0,
        updatedAt: now,
      ));

      var summary = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summary.totalZakatDue, equals(5000.0));
      expect(summary.remainingZakatOwed, equals(5000.0));

      // 1. Pay partial 3,000 QAR to Qatar Charity
      final p1Id = const Uuid().v4();
      await db.addZakatPayment(ZakatPayment(
        id: p1Id,
        householdId: household.id,
        obligationPeriod: '1447 AH',
        amount: 3000.0,
        paymentDate: now,
        recipient: 'قطر الخيرية',
      ));

      summary = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summary.totalZakatPaid, equals(3000.0));
      expect(summary.remainingZakatOwed, equals(2000.0));
      expect(summary.isObligationFulfilled, isFalse);

      // 2. Pay remaining 2,000 QAR to Red Crescent
      await db.addZakatPayment(ZakatPayment(
        id: const Uuid().v4(),
        householdId: household.id,
        obligationPeriod: '1447 AH',
        amount: 2000.0,
        paymentDate: now,
        recipient: 'الهلال الأحمر',
      ));

      summary = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summary.totalZakatPaid, equals(5000.0));
      expect(summary.remainingZakatOwed, equals(0.0));
      expect(summary.isObligationFulfilled, isTrue);

      // Verify deleting payment recalculates remaining owed
      await db.deleteZakatPayment(p1Id);
      summary = db.getZakatObligationSummary(obligationPeriod: '1447 AH');
      expect(summary.totalZakatPaid, equals(2000.0));
      expect(summary.remainingZakatOwed, equals(3000.0));
      expect(summary.isObligationFulfilled, isFalse);
    });
  });
}
