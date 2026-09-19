import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:incomegen/models/category_budget_override.dart';
import 'package:incomegen/models/member.dart';
import 'package:incomegen/models/transaction.dart';
import 'package:incomegen/services/database_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ahl_phase2_test_');
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

  group('Ahl Phase 2 — Budgeting & Household Split Verification', () {
    test('1. Category budget status computes actual spent, remaining buffer, and progress accurately', () async {
      final now = DateTime(2026, 3, 1);
      final household = db.getHousehold();
      final member = db.getMembers().first;
      final categories = db.getCategories();
      final groceriesCat = categories.firstWhere((c) => c.nameEn == 'Groceries & Household');

      // Baseline is 3500 QAR
      expect(groceriesCat.baselineMonthlyBudget, equals(3500.0));

      // Log 2000 QAR expense
      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: member.id,
        categoryId: groceriesCat.id,
        amount: 2000.0,
        type: 'expense',
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final statuses = db.getCategoryBudgetStatuses(now);
      final groceriesStatus = statuses.firstWhere((s) => s.category.id == groceriesCat.id);

      expect(groceriesStatus.effectiveBudget, equals(3500.0));
      expect(groceriesStatus.actualSpent, equals(2000.0));
      expect(groceriesStatus.remainingBudget, equals(1500.0));
      expect(groceriesStatus.hasOverride, isFalse);
      expect(groceriesStatus.isOverBudget, isFalse);
      expect(groceriesStatus.progress, closeTo(2000.0 / 3500.0, 0.001));
    });

    test('2. Seasonal Category Budget Override (Ramadan/Eid) takes precedence for specific month and reverts cleanly', () async {
      final ramadanMonth = DateTime(2026, 3, 1);
      final nextMonth = DateTime(2026, 4, 1);
      final household = db.getHousehold();
      final categories = db.getCategories();
      final groceriesCat = categories.firstWhere((c) => c.nameEn == 'Groceries & Household');

      // 1. Set Ramadan seasonal override (+2000 to make it 5500 QAR for 2026-03)
      final override = CategoryBudgetOverride(
        id: const Uuid().v4(),
        householdId: household.id,
        categoryId: groceriesCat.id,
        yearMonth: '2026-03',
        overrideBudget: 5500.0,
        note: 'ramadan: ولائم ومؤن رمضان',
      );
      await db.setCategoryBudgetOverride(override);

      // Verify Ramadan month has override and higher budget
      final ramadanStatuses = db.getCategoryBudgetStatuses(ramadanMonth);
      final ramadanGroceries = ramadanStatuses.firstWhere((s) => s.category.id == groceriesCat.id);
      expect(ramadanGroceries.effectiveBudget, equals(5500.0));
      expect(ramadanGroceries.hasOverride, isTrue);

      // Verify query helper returns the override
      final fetchedOverride = db.getCategoryBudgetOverride(groceriesCat.id, '2026-03');
      expect(fetchedOverride, isNotNull);
      expect(fetchedOverride?.overrideBudget, equals(5500.0));
      expect(fetchedOverride?.note, contains('ramadan'));

      // Verify subsequent month (2026-04) automatically reverts to baseline (3500 QAR)
      final nextMonthStatuses = db.getCategoryBudgetStatuses(nextMonth);
      final nextMonthGroceries = nextMonthStatuses.firstWhere((s) => s.category.id == groceriesCat.id);
      expect(nextMonthGroceries.effectiveBudget, equals(3500.0));
      expect(nextMonthGroceries.hasOverride, isFalse);

      // Remove the override and verify 2026-03 reverts back to baseline
      await db.removeCategoryBudgetOverride(groceriesCat.id, '2026-03');
      final revertedStatuses = db.getCategoryBudgetStatuses(ramadanMonth);
      final revertedGroceries = revertedStatuses.firstWhere((s) => s.category.id == groceriesCat.id);
      expect(revertedGroceries.effectiveBudget, equals(3500.0));
      expect(revertedGroceries.hasOverride, isFalse);
    });

    test('3. Over-budget detection and progress clamp behave correctly', () async {
      final now = DateTime(2026, 3, 15);
      final household = db.getHousehold();
      final member = db.getMembers().first;
      final diningCat = db.getCategories().firstWhere((c) => c.nameEn == 'Dining & Hospitality');

      // Baseline for Dining is 2000 QAR
      expect(diningCat.baselineMonthlyBudget, equals(2000.0));

      // Spend 2600 QAR (over budget by 600)
      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: member.id,
        categoryId: diningCat.id,
        amount: 2600.0,
        type: 'expense',
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final statuses = db.getCategoryBudgetStatuses(now);
      final diningStatus = statuses.firstWhere((s) => s.category.id == diningCat.id);

      expect(diningStatus.isOverBudget, isTrue);
      expect(diningStatus.remainingBudget, equals(-600.0));
      expect(diningStatus.progress, equals(1.0)); // Clamped at 1.0 for progress indicator safety
    });

    test('4. Household member contributor split calculates multi-member distribution cleanly', () async {
      final now = DateTime(2026, 3, 10);
      final household = db.getHousehold();
      final members = db.getMembers();
      final selfMember = members.firstWhere((m) => m.role == 'self');
      final spouseMember = members.firstWhere((m) => m.role == 'spouse');
      final cat = db.getCategories().first;

      // Add a third contributor (Elder Son)
      final sonMember = Member(
        id: const Uuid().v4(),
        householdId: household.id,
        name: 'سعود',
        role: 'contributor',
        colorHex: '#1E3A8A',
        isPrimary: false,
        createdAt: now,
      );
      await db.addMember(sonMember);

      // Log expenses:
      // Self: 5,000 QAR (50%)
      // Spouse: 3,000 QAR (30%)
      // Son: 2,000 QAR (20%)
      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: selfMember.id,
        categoryId: cat.id,
        amount: 5000.0,
        type: 'expense',
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: spouseMember.id,
        categoryId: cat.id,
        amount: 3000.0,
        type: 'expense',
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      await db.addTransaction(Transaction(
        id: const Uuid().v4(),
        householdId: household.id,
        memberId: sonMember.id,
        categoryId: cat.id,
        amount: 2000.0,
        type: 'expense',
        date: now,
        createdAt: now,
        updatedAt: now,
      ));

      final breakdown = db.getMemberSpendingBreakdown(now);
      expect(breakdown[selfMember.id], equals(5000.0));
      expect(breakdown[spouseMember.id], equals(3000.0));
      expect(breakdown[sonMember.id], equals(2000.0));

      final total = breakdown.values.fold<double>(0.0, (sum, val) => sum + val);
      expect(total, equals(10000.0));

      expect(breakdown[selfMember.id]! / total, closeTo(0.50, 0.001));
      expect(breakdown[spouseMember.id]! / total, closeTo(0.30, 0.001));
      expect(breakdown[sonMember.id]! / total, closeTo(0.20, 0.001));
    });

    test('5. Contributor Member CRUD works reliably', () async {
      final household = db.getHousehold();
      final newMember = Member(
        id: const Uuid().v4(),
        householdId: household.id,
        name: 'مساعد المنزل',
        role: 'dependent',
        colorHex: '#D97706',
        createdAt: DateTime.now(),
      );

      // Create
      await db.addMember(newMember);
      expect(db.getMemberById(newMember.id)?.name, equals('مساعد المنزل'));

      // Update
      final updated = newMember.copyWith(name: 'السائق الخاص', colorHex: '#059669');
      await db.updateMember(updated);
      final reloaded = db.getMemberById(newMember.id);
      expect(reloaded?.name, equals('السائق الخاص'));
      expect(reloaded?.colorHex, equals('#059669'));

      // Delete
      await db.deleteMember(newMember.id);
      expect(db.getMemberById(newMember.id), isNull);
    });

    test('6. DatabaseService overrideListenable fires reactively on override changes', () async {
      final household = db.getHousehold();
      final cat = db.getCategories().first;

      bool listenerFired = false;
      final listenable = db.overrideListenable;
      void listener() {
        listenerFired = true;
      }

      listenable.addListener(listener);

      await db.setCategoryBudgetOverride(CategoryBudgetOverride(
        id: const Uuid().v4(),
        householdId: household.id,
        categoryId: cat.id,
        yearMonth: '2026-05',
        overrideBudget: 7000.0,
        note: 'summer_break',
      ));

      expect(listenerFired, isTrue);

      listenable.removeListener(listener);
    });
  });
}
