import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/receipt.dart';
import 'paywall_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _receiptBoxName = 'receipts';
  static const String _settingsBoxName = 'settings';
  static const int maxFreeScans = 1;

  Box<Receipt>? _receiptBox;
  Box? _settingsBox;

  ValueListenable<Box<Receipt>> get listenable {
    if (_receiptBox == null) throw Exception('Database not initialized');
    return _receiptBox!.listenable();
  }

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ReceiptAdapter());
    _receiptBox = await Hive.openBox<Receipt>(_receiptBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    await migrateIfNeeded();
  }

  // --- Onboarding & Settings ---
  bool get hasSeenOnboarding {
    return _settingsBox?.get('hasSeenOnboarding', defaultValue: false) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    await _settingsBox?.put('hasSeenOnboarding', value);
  }

  bool get hasSeenCategoryPrompt {
    return _settingsBox?.get('hasSeenCategoryPrompt', defaultValue: false) ?? false;
  }

  Future<void> setHasSeenCategoryPrompt(bool value) async {
    await _settingsBox?.put('hasSeenCategoryPrompt', value);
  }

  String? get userRole {
    return _settingsBox?.get('userRole');
  }

  Future<void> setUserRole(String role) async {
    await _settingsBox?.put('userRole', role);
  }

  List<String> get activeCategories {
    final list = _settingsBox?.get('activeCategories');
    if (list != null && list is List) {
      return List<String>.from(list);
    }
    return ['Meals', 'Travel', 'Software', 'Office', 'Utilities', 'Other'];
  }

  Future<void> setActiveCategories(List<String> categories) async {
    await _settingsBox?.put('activeCategories', categories);
  }

  // --- Free Scan Check (Strictly 10 Free Scans then Hard Paywall) ---
  int get remainingFreeScans {
    final count = getReceiptCount();
    return (maxFreeScans - count).clamp(0, maxFreeScans);
  }

  bool get isFreeLimitReached {
    return getReceiptCount() >= maxFreeScans && !PaywallService().isPro.value;
  }

  Future<void> migrateIfNeeded() async {
    if (_receiptBox == null) return;
    
    bool needsSave = false;
    for (var i = 0; i < _receiptBox!.length; i++) {
      final receipt = _receiptBox!.getAt(i);
      if (receipt != null) {
        if (receipt.schemaVersion < 1) {
          receipt.schemaVersion = 1;
          needsSave = true;
        }
        if (needsSave) {
          await receipt.save();
        }
      }
    }
  }

  Future<void> saveReceipt(Receipt receipt) async {
    if (_receiptBox == null) throw Exception('Database not initialized');
    await _receiptBox!.put(receipt.id, receipt);
  }

  List<Receipt> getAllReceipts() {
    if (_receiptBox == null) throw Exception('Database not initialized');
    return _receiptBox!.values.toList();
  }

  Future<void> deleteReceipt(String id) async {
    if (_receiptBox == null) throw Exception('Database not initialized');
    await _receiptBox!.delete(id);
  }

  int getReceiptCount() {
    if (_receiptBox == null) throw Exception('Database not initialized');
    return _receiptBox!.length;
  }

  Future<void> clearAllReceipts() async {
    if (_receiptBox == null) throw Exception('Database not initialized');
    await _receiptBox!.clear();
  }
}
