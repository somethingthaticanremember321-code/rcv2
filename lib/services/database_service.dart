import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../models/household.dart';
import '../models/member.dart';
import '../models/category.dart';
import '../models/category_budget_override.dart';
import '../models/transaction.dart';
import '../models/zakat_asset.dart';
import '../models/zakat_payment.dart';

class MonthlySummary {
  final double totalIncome;
  final double totalExpense;
  final double netPosition; // totalIncome - totalExpense
  final int transactionCount;

  MonthlySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netPosition,
    required this.transactionCount,
  });
}

class CategoryBudgetStatus {
  final Category category;
  final double effectiveBudget;
  final double actualSpent;
  final bool hasOverride;

  CategoryBudgetStatus({
    required this.category,
    required this.effectiveBudget,
    required this.actualSpent,
    required this.hasOverride,
  });

  double get remainingBudget => effectiveBudget - actualSpent;
  double get progress => effectiveBudget > 0 ? (actualSpent / effectiveBudget).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => effectiveBudget > 0 && actualSpent > effectiveBudget;
}

class ZakatObligationSummary {
  final double totalGrossAssets;
  final double totalDeductibleLiabilities;
  final double netZakatableWealth;
  final double nisabThreshold;
  final bool isNisabMet;
  final double totalZakatDue;
  final double totalZakatPaid;
  final double remainingZakatOwed;
  final bool isObligationFulfilled;
  final String nisabStandard;
  final String zakatAuthorityGuidance;

  ZakatObligationSummary({
    required this.totalGrossAssets,
    required this.totalDeductibleLiabilities,
    required this.netZakatableWealth,
    required this.nisabThreshold,
    required this.isNisabMet,
    required this.totalZakatDue,
    required this.totalZakatPaid,
    required this.remainingZakatOwed,
    required this.isObligationFulfilled,
    required this.nisabStandard,
    required this.zakatAuthorityGuidance,
  });
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _householdBoxName = 'households';
  static const String _memberBoxName = 'members';
  static const String _categoryBoxName = 'categories';
  static const String _overrideBoxName = 'category_budget_overrides';
  static const String _transactionBoxName = 'transactions';
  static const String _zakatAssetBoxName = 'zakat_assets';
  static const String _zakatPaymentBoxName = 'zakat_payments';
  static const String _settingsBoxName = 'settings';

  Box<Household>? _householdBox;
  Box<Member>? _memberBox;
  Box<Category>? _categoryBox;
  Box<CategoryBudgetOverride>? _overrideBox;
  Box<Transaction>? _transactionBox;
  Box<ZakatAsset>? _zakatAssetBox;
  Box<ZakatPayment>? _zakatPaymentBox;
  Box? _settingsBox;

  final _uuid = const Uuid();

  // --- Listenables for reactive UI ---
  ValueListenable<Box<Transaction>> get transactionListenable {
    if (_transactionBox == null) throw Exception('Database not initialized');
    return _transactionBox!.listenable();
  }

  ValueListenable<Box<Member>> get memberListenable {
    if (_memberBox == null) throw Exception('Database not initialized');
    return _memberBox!.listenable();
  }

  ValueListenable<Box<Category>> get categoryListenable {
    if (_categoryBox == null) throw Exception('Database not initialized');
    return _categoryBox!.listenable();
  }

  ValueListenable<Box<ZakatAsset>> get zakatAssetListenable {
    if (_zakatAssetBox == null) throw Exception('Database not initialized');
    return _zakatAssetBox!.listenable();
  }

  ValueListenable<Box<CategoryBudgetOverride>> get overrideListenable {
    if (_overrideBox == null) throw Exception('Database not initialized');
    return _overrideBox!.listenable();
  }

  ValueListenable<Box<ZakatPayment>> get zakatPaymentListenable {
    if (_zakatPaymentBox == null) throw Exception('Database not initialized');
    return _zakatPaymentBox!.listenable();
  }

  /// Initialize Hive, register all 7 TypeAdapters, open boxes, and seed defaults
  Future<void> init({bool isUnitTest = false, String? subDir}) async {
    if (!isUnitTest) {
      await Hive.initFlutter(subDir);
    }

    _registerAdapters();

    _householdBox = await Hive.openBox<Household>(_householdBoxName);
    _memberBox = await Hive.openBox<Member>(_memberBoxName);
    _categoryBox = await Hive.openBox<Category>(_categoryBoxName);
    _overrideBox = await Hive.openBox<CategoryBudgetOverride>(_overrideBoxName);
    _transactionBox = await Hive.openBox<Transaction>(_transactionBoxName);
    _zakatAssetBox = await Hive.openBox<ZakatAsset>(_zakatAssetBoxName);
    _zakatPaymentBox = await Hive.openBox<ZakatPayment>(_zakatPaymentBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);

    await _seedDefaultsIfNeeded();
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(HouseholdAdapter());
    if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(MemberAdapter());
    if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(16)) Hive.registerAdapter(CategoryBudgetOverrideAdapter());
    if (!Hive.isAdapterRegistered(13)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(14)) Hive.registerAdapter(ZakatAssetAdapter());
    if (!Hive.isAdapterRegistered(15)) Hive.registerAdapter(ZakatPaymentAdapter());
  }

  Future<void> _seedDefaultsIfNeeded() async {
    if (_householdBox!.isEmpty) {
      final now = DateTime.now();
      final householdId = _uuid.v4();

      // 1. Initial Household
      final defaultHousehold = Household(
        id: householdId,
        name: 'عائلتنا', // Our Family
        currencyCode: 'QAR',
        currencySymbol: 'ر.ق',
        preferredLanguage: 'ar',
        nisabStandard: 'gold_85g',
        zakatAuthorityGuidance: 'qatar_awqaf',
        cachedGoldPricePerGram: 320.0,
        cachedSilverPricePerGram: 4.0,
        pricesUpdatedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await _householdBox!.put(householdId, defaultHousehold);

      // 2. Initial Members (Joint Household Contributor Model)
      final selfMember = Member(
        id: _uuid.v4(),
        householdId: householdId,
        name: 'أنا', // Self
        role: 'self',
        colorHex: '#0F6E56', // Deep teal
        isPrimary: true,
        createdAt: now,
      );

      final spouseMember = Member(
        id: _uuid.v4(),
        householdId: householdId,
        name: 'الزوج / الزوجة', // Spouse
        role: 'spouse',
        colorHex: '#C9962C', // Antique gold
        isPrimary: false,
        createdAt: now,
      );

      await _memberBox!.put(selfMember.id, selfMember);
      await _memberBox!.put(spouseMember.id, spouseMember);

      // 3. Initial GCC Core Categories
      final defaultCategories = [
        Category(
          id: _uuid.v4(),
          householdId: householdId,
          nameEn: 'Housing',
          nameAr: 'السكن',
          iconName: 'home',
          baselineMonthlyBudget: 8000.0,
          sortOrder: 1,
        ),
        Category(
          id: _uuid.v4(),
          householdId: householdId,
          nameEn: 'Groceries & Household',
          nameAr: 'المؤن والمقاضي',
          iconName: 'shopping_cart',
          baselineMonthlyBudget: 3500.0,
          sortOrder: 2,
        ),
        Category(
          id: _uuid.v4(),
          householdId: householdId,
          nameEn: 'Education',
          nameAr: 'التعليم',
          iconName: 'school',
          baselineMonthlyBudget: 4000.0,
          sortOrder: 3,
        ),
        Category(
          id: _uuid.v4(),
          householdId: householdId,
          nameEn: 'Transport & Fuel',
          nameAr: 'المواصلات والوقود',
          iconName: 'directions_car',
          baselineMonthlyBudget: 1500.0,
          sortOrder: 4,
        ),
        Category(
          id: _uuid.v4(),
          householdId: householdId,
          nameEn: 'Utilities & Telecom',
          nameAr: 'الفواتير والاتصالات',
          iconName: 'bolt',
          baselineMonthlyBudget: 1200.0,
          sortOrder: 5,
        ),
        Category(
          id: _uuid.v4(),
          householdId: householdId,
          nameEn: 'Domestic Services',
          nameAr: 'العمالة المنزلية',
          iconName: 'cleaning_services',
          baselineMonthlyBudget: 2500.0,
          sortOrder: 6,
        ),
        Category(
          id: _uuid.v4(),
          householdId: householdId,
          nameEn: 'Healthcare',
          nameAr: 'الرعاية الصحية',
          iconName: 'medical_services',
          baselineMonthlyBudget: 1000.0,
          sortOrder: 7,
        ),
        Category(
          id: _uuid.v4(),
          householdId: householdId,
          nameEn: 'Dining & Hospitality',
          nameAr: 'الضيافة والمطاعم',
          iconName: 'restaurant',
          baselineMonthlyBudget: 2000.0,
          sortOrder: 8,
        ),
      ];

      for (final cat in defaultCategories) {
        await _categoryBox!.put(cat.id, cat);
      }
    }
  }

  // ==========================================
  // --- HOUSEHOLD CRUD & SETTINGS ---
  // ==========================================

  Household getHousehold() {
    if (_householdBox == null || _householdBox!.isEmpty) {
      throw Exception('Database not initialized or household missing');
    }
    return _householdBox!.values.first;
  }

  Future<void> updateHousehold(Household updated) async {
    await _householdBox!.put(updated.id, updated);
  }

  bool get hasSeenOnboarding {
    return _settingsBox?.get('hasSeenOnboarding', defaultValue: false) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    await _settingsBox?.put('hasSeenOnboarding', value);
  }

  // ==========================================
  // --- MEMBERS CRUD (Household Split) ---
  // ==========================================

  List<Member> getMembers() {
    if (_memberBox == null) return [];
    return _memberBox!.values.toList();
  }

  Member? getMemberById(String id) {
    return _memberBox?.get(id);
  }

  Future<void> addMember(Member member) async {
    await _memberBox!.put(member.id, member);
  }

  Future<void> updateMember(Member member) async {
    await _memberBox!.put(member.id, member);
  }

  Future<void> deleteMember(String id) async {
    await _memberBox!.delete(id);
  }

  // ==========================================
  // --- CATEGORIES & SEASONAL BUDGET OVERRIDES ---
  // ==========================================

  List<Category> getCategories() {
    if (_categoryBox == null) return [];
    final list = _categoryBox!.values.toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Category? getCategoryById(String id) {
    return _categoryBox?.get(id);
  }

  Future<void> addCategory(Category category) async {
    await _categoryBox!.put(category.id, category);
  }

  Future<void> updateCategory(Category category) async {
    await _categoryBox!.put(category.id, category);
  }

  Future<void> deleteCategory(String id) async {
    await _categoryBox!.delete(id);
  }

  /// Calculates effective budget for a category for a specific month (format: "YYYY-MM").
  /// Checks CategoryBudgetOverride first (for Ramadan, Eid, etc.), fallback to baseline.
  double getEffectiveCategoryBudget(String categoryId, String yearMonth) {
    final cat = getCategoryById(categoryId);
    if (cat == null) return 0.0;

    final override = _overrideBox?.values.cast<CategoryBudgetOverride?>().firstWhere(
          (o) => o?.categoryId == categoryId && o?.yearMonth == yearMonth,
          orElse: () => null,
        );

    return override?.overrideBudget ?? cat.baselineMonthlyBudget;
  }

  Future<void> setCategoryBudgetOverride(CategoryBudgetOverride override) async {
    // If an override for this category & month already exists, overwrite it
    final existing = _overrideBox?.values.cast<CategoryBudgetOverride?>().firstWhere(
          (o) => o?.categoryId == override.categoryId && o?.yearMonth == override.yearMonth,
          orElse: () => null,
        );

    final id = existing?.id ?? override.id;
    await _overrideBox!.put(id, override.copyWith());
  }

  Future<void> removeCategoryBudgetOverride(String categoryId, String yearMonth) async {
    final existing = _overrideBox?.values.cast<CategoryBudgetOverride?>().firstWhere(
          (o) => o?.categoryId == categoryId && o?.yearMonth == yearMonth,
          orElse: () => null,
        );
    if (existing != null) {
      await _overrideBox!.delete(existing.id);
    }
  }

  CategoryBudgetOverride? getCategoryBudgetOverride(String categoryId, String yearMonth) {
    return _overrideBox?.values.cast<CategoryBudgetOverride?>().firstWhere(
          (o) => o?.categoryId == categoryId && o?.yearMonth == yearMonth,
          orElse: () => null,
        );
  }

  // ==========================================
  // --- TRANSACTIONS (Core Loop) ---
  // ==========================================

  Future<void> addTransaction(Transaction tx) async {
    await _transactionBox!.put(tx.id, tx);
  }

  Future<void> updateTransaction(Transaction tx) async {
    await _transactionBox!.put(tx.id, tx);
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionBox!.delete(id);
  }

  List<Transaction> getTransactions({
    DateTime? month,
    String? memberId,
    String? categoryId,
    String? type,
  }) {
    if (_transactionBox == null) return [];
    var list = _transactionBox!.values.toList();

    if (month != null) {
      list = list.where((t) => t.date.year == month.year && t.date.month == month.month).toList();
    }
    if (memberId != null) {
      list = list.where((t) => t.memberId == memberId).toList();
    }
    if (categoryId != null) {
      list = list.where((t) => t.categoryId == categoryId).toList();
    }
    if (type != null) {
      list = list.where((t) => t.type == type).toList();
    }

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Calculates net household position for a month
  MonthlySummary getMonthlySummary(DateTime month) {
    final txs = getTransactions(month: month);
    double income = 0.0;
    double expense = 0.0;

    for (final t in txs) {
      if (t.isIncome) {
        income += t.amount;
      } else if (t.isExpense) {
        expense += t.amount;
      }
    }

    return MonthlySummary(
      totalIncome: income,
      totalExpense: expense,
      netPosition: income - expense,
      transactionCount: txs.length,
    );
  }

  /// Breakdown of monthly spending attributed per member
  Map<String, double> getMemberSpendingBreakdown(DateTime month) {
    final txs = getTransactions(month: month, type: 'expense');
    final map = <String, double>{};

    for (final t in txs) {
      map[t.memberId] = (map[t.memberId] ?? 0.0) + t.amount;
    }
    return map;
  }

  /// Budget vs Actual breakdown per category for a month
  List<CategoryBudgetStatus> getCategoryBudgetStatuses(DateTime month) {
    final categories = getCategories();
    final yearMonth = DateFormat('yyyy-MM').format(month);
    final txs = getTransactions(month: month, type: 'expense');

    final spendingMap = <String, double>{};
    for (final t in txs) {
      spendingMap[t.categoryId] = (spendingMap[t.categoryId] ?? 0.0) + t.amount;
    }

    return categories.map((cat) {
      final override = _overrideBox?.values.cast<CategoryBudgetOverride?>().firstWhere(
            (o) => o?.categoryId == cat.id && o?.yearMonth == yearMonth,
            orElse: () => null,
          );

      final effectiveBudget = override?.overrideBudget ?? cat.baselineMonthlyBudget;
      final actualSpent = spendingMap[cat.id] ?? 0.0;

      return CategoryBudgetStatus(
        category: cat,
        effectiveBudget: effectiveBudget,
        actualSpent: actualSpent,
        hasOverride: override != null,
      );
    }).toList();
  }

  // ==========================================
  // --- ZAKAT ASSETS & OBLIGATION TRACKER ---
  // ==========================================

  List<ZakatAsset> getZakatAssets({String? memberId}) {
    if (_zakatAssetBox == null) return [];
    var list = _zakatAssetBox!.values.toList();
    if (memberId != null) {
      list = list.where((a) => a.memberId == memberId).toList();
    }
    return list;
  }

  Future<void> addZakatAsset(ZakatAsset asset) async {
    await _zakatAssetBox!.put(asset.id, asset);
  }

  Future<void> updateZakatAsset(ZakatAsset asset) async {
    await _zakatAssetBox!.put(asset.id, asset);
  }

  Future<void> deleteZakatAsset(String id) async {
    await _zakatAssetBox!.delete(id);
  }

  List<ZakatPayment> getZakatPayments({String? obligationPeriod, String? memberId}) {
    if (_zakatPaymentBox == null) return [];
    var list = _zakatPaymentBox!.values.toList();
    if (obligationPeriod != null) {
      list = list.where((p) => p.obligationPeriod == obligationPeriod).toList();
    }
    if (memberId != null) {
      list = list.where((p) => p.memberId == memberId).toList();
    }
    list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return list;
  }

  Future<void> addZakatPayment(ZakatPayment payment) async {
    await _zakatPaymentBox!.put(payment.id, payment);
  }

  Future<void> deleteZakatPayment(String id) async {
    await _zakatPaymentBox!.delete(id);
  }

  /// Rigorous Zakat calculation based on Nisab standard (Gold 85g or Silver 595g)
  /// deducting short-term liabilities and tracking contributions against the obligation.
  ZakatObligationSummary getZakatObligationSummary({
    required String obligationPeriod,
    String? memberId,
  }) {
    final household = getHousehold();
    final assets = getZakatAssets(memberId: memberId);
    final payments = getZakatPayments(obligationPeriod: obligationPeriod, memberId: memberId);

    double totalGross = 0.0;
    double totalLiabilities = 0.0;

    for (final a in assets) {
      totalGross += a.cashValue;
      totalLiabilities += a.deductibleLiabilities;
    }

    final netZakatableWealth = (totalGross - totalLiabilities).clamp(0.0, double.infinity);

    // Nisab calculation
    final isGold = household.nisabStandard == 'gold_85g';
    final double spotPrice = isGold
        ? (household.cachedGoldPricePerGram ?? 320.0)
        : (household.cachedSilverPricePerGram ?? 4.0);
    final double gramRequirement = isGold ? 85.0 : 595.0;
    final double nisabThreshold = gramRequirement * spotPrice;

    final bool isNisabMet = netZakatableWealth >= nisabThreshold;
    // 2.5% standard zakat rate on zakatable assets
    final double totalZakatDue = isNisabMet ? (netZakatableWealth * 0.025) : 0.0;

    double totalPaid = 0.0;
    for (final p in payments) {
      totalPaid += p.amount;
    }

    final remainingOwed = (totalZakatDue - totalPaid).clamp(0.0, double.infinity);
    final isFulfilled = totalZakatDue > 0 && totalPaid >= totalZakatDue;

    return ZakatObligationSummary(
      totalGrossAssets: totalGross,
      totalDeductibleLiabilities: totalLiabilities,
      netZakatableWealth: netZakatableWealth,
      nisabThreshold: nisabThreshold,
      isNisabMet: isNisabMet,
      totalZakatDue: totalZakatDue,
      totalZakatPaid: totalPaid,
      remainingZakatOwed: remainingOwed,
      isObligationFulfilled: isFulfilled,
      nisabStandard: household.nisabStandard,
      zakatAuthorityGuidance: household.zakatAuthorityGuidance,
    );
  }

  /// Clean teardown for unit testing
  Future<void> close() async {
    await _householdBox?.close();
    await _memberBox?.close();
    await _categoryBox?.close();
    await _overrideBox?.close();
    await _transactionBox?.close();
    await _zakatAssetBox?.close();
    await _zakatPaymentBox?.close();
    await _settingsBox?.close();
  }
}
