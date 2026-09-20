import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/api_config.dart';
import 'analytics_service.dart';

/// Presentation model representing an Ahl Pro subscription plan
class AhlSubscriptionPlan {
  final String id;
  final String titleEn;
  final String titleAr;
  final String priceDisplayEn;
  final String priceDisplayAr;
  final String periodEn;
  final String periodAr;
  final String? savingsBadgeEn;
  final String? savingsBadgeAr;
  final bool hasTrial;
  final Package? rcPackage;

  const AhlSubscriptionPlan({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.priceDisplayEn,
    required this.priceDisplayAr,
    required this.periodEn,
    required this.periodAr,
    this.savingsBadgeEn,
    this.savingsBadgeAr,
    this.hasTrial = false,
    this.rcPackage,
  });
}

class PaywallService {
  static final PaywallService _instance = PaywallService._internal();
  factory PaywallService() => _instance;
  PaywallService._internal();

  static const String _appleApiKey = ApiConfig.revenueCatAppleApiKey;
  static const String _googleApiKey = ApiConfig.revenueCatGoogleApiKey;

  static const bool _forceFreePro = bool.fromEnvironment('FREE_PRO', defaultValue: false);
  final ValueNotifier<bool> isPro = ValueNotifier(_forceFreePro);

  // Freemium Entitlement Gate Limits
  static const int freeMemberLimit = 2;
  static const int freeSeasonalOverrideLimit = 1;
  static const int freeZakatAssetLimit = 3;

  bool get isProUser => isPro.value;

  /// Check whether another household member can be added
  bool canAddMember(int currentCount) => isProUser || currentCount < freeMemberLimit;

  /// Check whether an additional seasonal budget override can be added for the month
  bool canAddSeasonalOverride(int currentMonthOverrideCount) =>
      isProUser || currentMonthOverrideCount < freeSeasonalOverrideLimit;

  /// Check whether an additional zakatable asset can be tracked
  bool canAddZakatAsset(int currentCount) => isProUser || currentCount < freeZakatAssetLimit;

  /// Check whether data export is allowed
  bool get canExportData => isProUser;

  /// Direct override for unit and integration testing
  void setProForTesting(bool value) {
    isPro.value = value;
  }

  void togglePro() {
    isPro.value = !isPro.value;
  }

  Future<void> init() async {
    if (_forceFreePro) {
      isPro.value = true;
      return;
    }
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
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
    } catch (e) {
      debugPrint('[PaywallService] RevenueCat init safely skipped/failed: $e');
    }
  }

  Future<void> checkProStatus() async {
    if (_forceFreePro) {
      isPro.value = true;
      return;
    }
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final customerInfo = await Purchases.getCustomerInfo();
        isPro.value = customerInfo.entitlements.all['pro']?.isActive ?? false;
      }
    } catch (e) {
      debugPrint('[PaywallService] Failed to check pro status: $e');
    }
  }

  Future<bool> purchasePlan(AhlSubscriptionPlan plan) async {
    if (_forceFreePro) {
      isPro.value = true;
      AnalyticsService().paywallConverted(
        planId: plan.id,
        isPro: true,
      );
      return true;
    }
    try {
      if (plan.rcPackage != null && (Platform.isAndroid || Platform.isIOS)) {
        final result = await Purchases.purchase(PurchaseParams.package(plan.rcPackage!));
        isPro.value = result.customerInfo.entitlements.all['pro']?.isActive ?? false;
      } else {
        // Mock / Sandbox / Testing purchase
        isPro.value = true;
      }

      AnalyticsService().paywallConverted(
        planId: plan.id,
        isPro: isPro.value,
      );
      return isPro.value;
    } catch (e) {
      debugPrint('[PaywallService] Failed to purchase: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    if (_forceFreePro) {
      isPro.value = true;
      AnalyticsService().paywallRestored(isPro: true);
      return true;
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final customerInfo = await Purchases.restorePurchases();
        isPro.value = customerInfo.entitlements.all['pro']?.isActive ?? false;
      } else {
        isPro.value = true;
      }

      AnalyticsService().paywallRestored(isPro: isPro.value);
      return isPro.value;
    } catch (e) {
      debugPrint('[PaywallService] Failed to restore purchases: $e');
      AnalyticsService().paywallRestored(isPro: false);
      return false;
    }
  }

  /// Returns packages from RevenueCat if available, or returns high-quality fallback plans
  Future<List<AhlSubscriptionPlan>> getAvailablePlans({String currencySymbol = 'QAR'}) async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final offerings = await Purchases.getOfferings();
        if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
          final packages = offerings.current!.availablePackages;
          return packages.map((pkg) {
            final isAnnual = pkg.packageType == PackageType.annual;
            final priceStr = pkg.storeProduct.priceString;
            return AhlSubscriptionPlan(
              id: pkg.identifier,
              titleEn: isAnnual ? 'Ahl Pro Annual' : 'Ahl Pro Monthly',
              titleAr: isAnnual ? 'أهل برو — سنوي' : 'أهل برو — شهري',
              priceDisplayEn: isAnnual ? '$priceStr / year' : '$priceStr / month',
              priceDisplayAr: isAnnual ? '$priceStr / سنوياً' : '$priceStr / شهرياً',
              periodEn: isAnnual ? 'Billed annually' : 'Billed monthly',
              periodAr: isAnnual ? 'يُدفع سنوياً' : 'يُدفع شهرياً',
              savingsBadgeEn: isAnnual ? 'SAVE 45%' : null,
              savingsBadgeAr: isAnnual ? 'وفّر ٤٥٪' : null,
              hasTrial: isAnnual,
              rcPackage: pkg,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[PaywallService] Falling back to default plan definitions: $e');
    }

    // Default premium plans tailored for GCC households
    return [
      AhlSubscriptionPlan(
        id: 'ahl_pro_annual',
        titleEn: 'Ahl Pro Annual',
        titleAr: 'أهل برو — سنوي (الأفضل)',
        priceDisplayEn: '199.99 $currencySymbol / year',
        priceDisplayAr: '١٩٩.٩٩ $currencySymbol / سنوياً',
        periodEn: 'Equivalent to ~16.6 $currencySymbol/mo',
        periodAr: 'يعادل ~١٦.٦ $currencySymbol شهرياً',
        savingsBadgeEn: 'SAVE 45%',
        savingsBadgeAr: 'وفّر ٤٥٪',
        hasTrial: true,
      ),
      AhlSubscriptionPlan(
        id: 'ahl_pro_monthly',
        titleEn: 'Ahl Pro Monthly',
        titleAr: 'أهل برو — شهري',
        priceDisplayEn: '29.99 $currencySymbol / month',
        priceDisplayAr: '٢٩.٩٩ $currencySymbol / شهرياً',
        periodEn: 'Flexible monthly billing',
        periodAr: 'اشتراك شهري مرن',
        hasTrial: false,
      ),
    ];
  }
}
