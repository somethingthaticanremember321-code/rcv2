import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/api_config.dart';
import 'analytics_service.dart';

/// Presentation model representing a Mali Pro subscription plan
class MaliSubscriptionPlan {
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
  final bool isLifetime;
  final Package? rcPackage;

  const MaliSubscriptionPlan({
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
    this.isLifetime = false,
    this.rcPackage,
  });
}

// Backward compatibility alias
typedef AhlSubscriptionPlan = MaliSubscriptionPlan;

class PaywallService {
  static final PaywallService _instance = PaywallService._internal();
  factory PaywallService() => _instance;
  PaywallService._internal();

  static const String _appleApiKey = ApiConfig.revenueCatAppleApiKey;
  static const String _googleApiKey = ApiConfig.revenueCatGoogleApiKey;

  final ValueNotifier<bool> isPro = ValueNotifier(false);

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
    if (kDebugMode) {
      isPro.value = value;
    }
  }

  void togglePro() {
    if (kDebugMode) {
      isPro.value = !isPro.value;
    }
  }

  Future<void> init() async {
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

  bool _isEntitlementActive(CustomerInfo customerInfo) {
    return (customerInfo.entitlements.all['pro']?.isActive ?? false) ||
        (customerInfo.entitlements.all['premium']?.isActive ?? false) ||
        (customerInfo.entitlements.all['mali_pro']?.isActive ?? false) ||
        customerInfo.entitlements.active.isNotEmpty;
  }

  Future<void> checkProStatus() async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final customerInfo = await Purchases.getCustomerInfo();
        isPro.value = _isEntitlementActive(customerInfo);
      }
    } catch (e) {
      debugPrint('[PaywallService] Failed to check pro status: $e');
      isPro.value = false;
    }
  }

  Future<bool> purchasePlan(MaliSubscriptionPlan plan) async {
    try {
      if (plan.rcPackage != null && (Platform.isAndroid || Platform.isIOS)) {
        final result = await Purchases.purchase(PurchaseParams.package(plan.rcPackage!));
        isPro.value = _isEntitlementActive(result.customerInfo);
      } else if (kDebugMode) {
        // Mock purchase exclusively for local developer testing
        isPro.value = true;
      } else {
        // In production release, never grant free pro without active Google Play purchase
        debugPrint('[PaywallService] Purchase rejected: No valid RevenueCat package or store active');
        isPro.value = false;
        return false;
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
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final customerInfo = await Purchases.restorePurchases();
        isPro.value = _isEntitlementActive(customerInfo);
      } else if (kDebugMode) {
        isPro.value = true;
      } else {
        isPro.value = false;
        return false;
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
  Future<List<MaliSubscriptionPlan>> getAvailablePlans({String currencySymbol = 'SAR'}) async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final offerings = await Purchases.getOfferings();
        if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
          final packages = offerings.current!.availablePackages;
          return packages.map((pkg) {
            final isAnnual = pkg.packageType == PackageType.annual;
            final isLifetime = pkg.packageType == PackageType.lifetime ||
                pkg.identifier.toLowerCase().contains('lifetime');
            final priceStr = pkg.storeProduct.priceString;

            String titleEn;
            String titleAr;
            String periodEn;
            String periodAr;
            String? savingsBadgeEn;
            String? savingsBadgeAr;

            if (isLifetime) {
              titleEn = 'Mali Lifetime';
              titleAr = 'مالي مدى الحياة';
              periodEn = 'One-time payment • Own forever';
              periodAr = 'دفع لمرة واحدة • امتلاك دائم';
              savingsBadgeEn = 'FOUNDER PASS';
              savingsBadgeAr = 'باقة التأسيس';
            } else if (isAnnual) {
              titleEn = 'Mali Pro Annual';
              titleAr = 'مالي برو — سنوي (الأفضل)';
              periodEn = 'Billed annually • 7-day free trial';
              periodAr = 'يُدفع سنوياً • تجربة مجانية ٧ أيام';
              savingsBadgeEn = 'SAVE 55%';
              savingsBadgeAr = 'وفّر ٥٥٪';
            } else {
              titleEn = 'Mali Pro Monthly';
              titleAr = 'مالي برو — شهري';
              periodEn = 'Flexible monthly billing';
              periodAr = 'اشتراك شهري مرن';
            }

            return MaliSubscriptionPlan(
              id: pkg.identifier,
              titleEn: titleEn,
              titleAr: titleAr,
              priceDisplayEn: isLifetime ? priceStr : (isAnnual ? '$priceStr / year' : '$priceStr / month'),
              priceDisplayAr: isLifetime ? priceStr : (isAnnual ? '$priceStr / سنوياً' : '$priceStr / شهرياً'),
              periodEn: periodEn,
              periodAr: periodAr,
              savingsBadgeEn: savingsBadgeEn,
              savingsBadgeAr: savingsBadgeAr,
              hasTrial: isAnnual,
              isLifetime: isLifetime,
              rcPackage: pkg,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[PaywallService] Falling back to default plan definitions: $e');
    }

    // Default premium plans tailored for GCC and global consumers
    return [
      MaliSubscriptionPlan(
        id: 'mali_pro_annual',
        titleEn: 'Mali Pro Annual',
        titleAr: 'مالي برو — سنوي (الأفضل)',
        priceDisplayEn: '79.99 $currencySymbol / year',
        priceDisplayAr: '٧٩.٩٩ $currencySymbol / سنوياً',
        periodEn: 'Equivalent to ~6.6 $currencySymbol/mo • 7-Day Free Trial',
        periodAr: 'يعادل ~٦.٦ $currencySymbol شهرياً • تجربة مجانية ٧ أيام',
        savingsBadgeEn: 'SAVE 55%',
        savingsBadgeAr: 'وفّر ٥٥٪',
        hasTrial: true,
        isLifetime: false,
      ),
      MaliSubscriptionPlan(
        id: 'mali_pro_monthly',
        titleEn: 'Mali Pro Monthly',
        titleAr: 'مالي برو — شهري',
        priceDisplayEn: '14.99 $currencySymbol / month',
        priceDisplayAr: '١٤.٩٩ $currencySymbol / شهرياً',
        periodEn: 'Flexible monthly billing',
        periodAr: 'اشتراك شهري مرن • إلغاء بأي وقت',
        hasTrial: false,
        isLifetime: false,
      ),
      MaliSubscriptionPlan(
        id: 'mali_pro_lifetime',
        titleEn: 'Mali Lifetime',
        titleAr: 'مالي مدى الحياة',
        priceDisplayEn: '149.99 $currencySymbol',
        priceDisplayAr: '١٤٩.٩٩ $currencySymbol',
        periodEn: 'Pay once • Permanent updates • Zero renewals',
        periodAr: 'دفع لمرة واحدة • تحديثات دائمة • بلا فواتير متكررة',
        savingsBadgeEn: 'FOUNDER PASS',
        savingsBadgeAr: 'امتلاك دائم',
        hasTrial: false,
        isLifetime: true,
      ),
    ];
  }
}
