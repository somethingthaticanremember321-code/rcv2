import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/api_config.dart';

class PaywallService {
  static final PaywallService _instance = PaywallService._internal();
  factory PaywallService() => _instance;
  PaywallService._internal();

  static const String _appleApiKey = ApiConfig.revenueCatAppleApiKey;
  static const String _googleApiKey = ApiConfig.revenueCatGoogleApiKey;

  static const bool _forceFreePro = bool.fromEnvironment('FREE_PRO', defaultValue: false);
  ValueNotifier<bool> isPro = ValueNotifier(_forceFreePro);

  void togglePro() {
    isPro.value = !isPro.value;
  }

  Future<void> init() async {
    if (_forceFreePro) {
      isPro.value = true;
      return;
    }
    if (kIsWeb) return; // RevenueCat does not support web directly in this way
    
    await Purchases.setLogLevel(LogLevel.info);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      await checkProStatus();
    }
  }

  Future<void> checkProStatus() async {
    if (_forceFreePro) {
      isPro.value = true;
      return;
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // Assuming 'pro' is the entitlement identifier in RevenueCat
      isPro.value = customerInfo.entitlements.all['pro']?.isActive ?? false;
    } catch (e) {
      // In case of network error, err on the side of caution (don't grant pro)
      debugPrint("Failed to check pro status: $e");
    }
  }

  Future<bool> purchasePro(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      isPro.value = result.customerInfo.entitlements.all['pro']?.isActive ?? false;
      return isPro.value;
    } catch (e) {
      debugPrint("Failed to purchase: $e");
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      isPro.value = customerInfo.entitlements.all['pro']?.isActive ?? false;
      return isPro.value;
    } catch (e) {
      debugPrint("Failed to restore purchases: $e");
      return false;
    }
  }

  Future<List<Package>> getPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      debugPrint("Failed to get packages: $e");
    }
    return [];
  }
}
