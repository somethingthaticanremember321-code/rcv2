import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final Posthog _posthog = Posthog();

  Future<void> capture(String eventName, {Map<String, Object>? properties}) async {
    try {
      if (kDebugMode) {
        debugPrint('[Analytics] Event: $eventName, Properties: $properties');
      }
      await _posthog.capture(
        eventName: eventName,
        properties: properties,
      );
    } catch (e) {
      debugPrint('[Analytics] Failed to capture $eventName: $e');
    }
  }

  void transactionLogged({
    required String type,
    required double amount,
    required String categoryId,
    required String memberRole,
  }) {
    capture('transaction_logged', properties: {
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'member_role': memberRole,
    });
  }

  void onboardingCompleted({required String language, required String currencyCode}) {
    capture('onboarding_completed', properties: {
      'language': language,
      'currency_code': currencyCode,
    });
  }

  void appRated({required int rating}) {
    capture('app_rated', properties: {
      'rating': rating,
    });
  }

  void paywallImpression({required String trigger}) {
    capture('paywall_impression', properties: {
      'trigger': trigger,
    });
  }

  void paywallConverted({required String planId, required bool isPro}) {
    capture('paywall_converted', properties: {
      'plan_id': planId,
      'is_pro': isPro,
    });
  }

  void paywallRestored({required bool isPro}) {
    capture('paywall_restored', properties: {
      'is_pro': isPro,
    });
  }
}
