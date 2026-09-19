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

  void scanAttemptStarted({required String source, required int attemptNumber}) {
    capture('scan_attempt_started', properties: {
      'source': source,
      'attempt_number': attemptNumber,
    });
  }

  void scanCompleted({
    required bool success,
    required int durationMs,
    int fieldsFilled = 0,
    bool isLowConfidence = false,
  }) {
    capture('scan_completed', properties: {
      'success': success,
      'duration_ms': durationMs,
      'fields_filled': fieldsFilled,
      'is_low_confidence': isLowConfidence,
    });
  }

  void scanFailed({required String reason, required int attemptNumber}) {
    capture('scan_failed', properties: {
      'reason': reason,
      'attempt_number': attemptNumber,
    });
  }

  void receiptVerified({required int editedFieldsCount, required bool wasManual}) {
    capture('receipt_verified', properties: {
      'edited_fields_count': editedFieldsCount,
      'was_manual': wasManual,
    });
  }

  void receiptSaved({
    required String category,
    required bool isFirstReceipt,
    double? amount,
  }) {
    capture('receipt_saved', properties: {
      'category': category,
      'is_first_receipt': isFirstReceipt,
      'amount': amount ?? 0.0,
    });
  }

  void paywallImpression({
    required String trigger,
    required int attemptsUsed,
    required int savedReceiptCount,
  }) {
    capture('paywall_impression', properties: {
      'trigger': trigger,
      'attempts_used': attemptsUsed,
      'saved_receipt_count': savedReceiptCount,
    });
  }

  void planSelected({required String planType}) {
    capture('plan_selected', properties: {
      'plan_type': planType,
    });
  }

  void purchaseCompleted({required String planType}) {
    capture('purchase_completed', properties: {
      'plan_type': planType,
    });
  }

  void csvExported({required int receiptCount}) {
    capture('csv_exported', properties: {
      'receipt_count': receiptCount,
    });
  }

  void roleSelected({required String role}) {
    capture('role_selected', properties: {
      'role': role,
    });
  }
}
