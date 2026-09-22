import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/household.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import '../models/zakat_asset.dart';
import '../models/zakat_payment.dart';
import 'database_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// UTF-8 Byte Order Mark to ensure Excel correctly renders Arabic scripts
  static const String _utf8Bom = '\uFEFF';

  /// Generates a clean CSV of all transactions with contributor attribution
  String generateTransactionsCsv({
    required Household household,
    required List<Transaction> transactions,
    required Map<String, Category> categories,
    required Map<String, Member> members,
  }) {
    final isArabic = household.preferredLanguage == 'ar';
    final buffer = StringBuffer();
    buffer.write(_utf8Bom);

    // Headers
    if (isArabic) {
      buffer.writeln('التاريخ,النوع,المبلغ,العملة,التصنيف,المساهم,الدور,ملاحظات');
    } else {
      buffer.writeln('Date,Type,Amount,Currency,Category,Contributor,Role,Notes');
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    for (final tx in transactions) {
      final category = categories[tx.categoryId];
      final member = members[tx.memberId];

      final dateStr = dateFormat.format(tx.date);
      final typeStr = isArabic
          ? (tx.type == 'expense' ? 'مصروف' : 'دخل')
          : (tx.type == 'expense' ? 'Expense' : 'Income');
      final amountStr = tx.amount.toStringAsFixed(2);
      final currencyStr = tx.originalCurrency ?? household.currencyCode;
      final categoryStr = category != null
          ? (isArabic ? category.nameAr : category.nameEn)
          : (isArabic ? 'عام' : 'General');
      final memberStr = member?.name ?? (isArabic ? 'غير محدد' : 'Unassigned');
      final roleStr = member?.role ?? '';
      final notesClean = (tx.note ?? '').replaceAll('"', '""');

      buffer.writeln(
        '"$dateStr","$typeStr",$amountStr,"$currencyStr","$categoryStr","$memberStr","$roleStr","$notesClean"',
      );
    }

    return buffer.toString();
  }

  /// Generates a comprehensive Shariah Zakat audit report in CSV format
  String generateZakatReportCsv({
    required Household household,
    required ZakatObligationSummary summary,
    required List<ZakatAsset> assets,
    required List<ZakatPayment> payments,
    String obligationPeriod = 'Current Period',
  }) {
    final isArabic = household.preferredLanguage == 'ar';
    final buffer = StringBuffer();
    buffer.write(_utf8Bom);

    final dateFormat = DateFormat('yyyy-MM-dd');
    final currency = household.currencySymbol;

    if (isArabic) {
      buffer.writeln('=== تقرير حساب الزكاة الشرعي — تطبيق مالي ===');
      buffer.writeln('تاريخ التقرير,"${dateFormat.format(DateTime.now())}"');
      buffer.writeln('فترة الوجوب,"$obligationPeriod"');
      buffer.writeln('معيار النصاب,"${summary.nisabStandard == 'gold' ? 'ذهب (٨٥ غرام عيار ٢٤)' : 'فضة (٥٩٥ غرام)'}"');
      buffer.writeln('قيمة النصاب الحالية,${summary.nisabThreshold.toStringAsFixed(2)},$currency');
      buffer.writeln('إجمالي الأصول الزكوية,${summary.totalGrossAssets.toStringAsFixed(2)},$currency');
      buffer.writeln('الالتزامات والديون المخصومة,${summary.totalDeductibleLiabilities.toStringAsFixed(2)},$currency');
      buffer.writeln('صافي الوعاء الزكوي,${summary.netZakatableWealth.toStringAsFixed(2)},$currency');
      buffer.writeln('حالة بلوغ النصاب,"${summary.isNisabMet ? 'متحقق' : 'غير بالغ للنصاب'}"');
      buffer.writeln('مقدار الزكاة الواجبة (٢.٥٪),${summary.totalZakatDue.toStringAsFixed(2)},$currency');
      buffer.writeln('إجمالي ما تم إخراجه,${summary.totalZakatPaid.toStringAsFixed(2)},$currency');
      buffer.writeln('المتبقي في الذمة,${summary.remainingZakatOwed.toStringAsFixed(2)},$currency');
      buffer.writeln('');
      buffer.writeln('--- تفصيل الأصول الزكوية ---');
      buffer.writeln('اسم الأصل,النوع,العيار,الوزن (غرام),القيمة الإجمالية,الديون المخصومة,صافي الوعاء,تاريخ بدء الحول,اكتمل الحول؟');

      for (final a in assets) {
        final hawlDateStr = a.hawlStartDate != null ? dateFormat.format(a.hawlStartDate!) : '-';
        final daysElapsed = a.hawlStartDate != null ? DateTime.now().difference(a.hawlStartDate!).inDays : 0;
        final isHawlElapsed = a.hawlStartDate != null && daysElapsed >= 354;
        final hawlStatus = isHawlElapsed ? 'نعم (واجبة)' : 'جاري';
        final karatStr = a.purityKarat?.toString() ?? '-';
        buffer.writeln(
          '"${a.name}","${a.assetType}","$karatStr","${a.weightGrams ?? 0}",${a.cashValue.toStringAsFixed(2)},${a.deductibleLiabilities.toStringAsFixed(2)},${a.netZakatableValue.toStringAsFixed(2)},"$hawlDateStr","$hawlStatus"',
        );
      }

      buffer.writeln('');
      buffer.writeln('--- سجل دفعات وتوزيع الزكاة ---');
      buffer.writeln('التاريخ,الجهة / المستحق,المبلغ,العملة,رقم الإيصال / الملاحظات');

      for (final p in payments) {
        final pDate = dateFormat.format(p.paymentDate);
        final notes = (p.note ?? '').replaceAll('"', '""');
        final recipient = (p.recipient ?? 'جهة غير محددة').replaceAll('"', '""');
        buffer.writeln(
          '"$pDate","$recipient",${p.amount.toStringAsFixed(2)},"$currency","$notes"',
        );
      }
    } else {
      buffer.writeln('=== Shariah Zakat Audit Report — Mali App ===');
      buffer.writeln('Report Date,"${dateFormat.format(DateTime.now())}"');
      buffer.writeln('Obligation Period,"$obligationPeriod"');
      buffer.writeln('Nisab Standard,"${summary.nisabStandard == 'gold' ? 'Gold (85g 24K)' : 'Silver (595g)'}"');
      buffer.writeln('Nisab Threshold,${summary.nisabThreshold.toStringAsFixed(2)},$currency');
      buffer.writeln('Total Gross Assets,${summary.totalGrossAssets.toStringAsFixed(2)},$currency');
      buffer.writeln('Deductible Liabilities,${summary.totalDeductibleLiabilities.toStringAsFixed(2)},$currency');
      buffer.writeln('Net Zakatable Wealth,${summary.netZakatableWealth.toStringAsFixed(2)},$currency');
      buffer.writeln('Nisab Reached,"${summary.isNisabMet ? 'Yes' : 'No'}"');
      buffer.writeln('Zakat Obligation (2.5%),${summary.totalZakatDue.toStringAsFixed(2)},$currency');
      buffer.writeln('Total Paid to Date,${summary.totalZakatPaid.toStringAsFixed(2)},$currency');
      buffer.writeln('Remaining Balance Due,${summary.remainingZakatOwed.toStringAsFixed(2)},$currency');
      buffer.writeln('');
      buffer.writeln('--- Zakatable Assets Breakdown ---');
      buffer.writeln('Asset Name,Type,Karat,Weight (g),Gross Valuation,Deductible Debt,Net Zakatable,Hawl Start Date,Hawl Elapsed?');

      for (final a in assets) {
        final hawlDateStr = a.hawlStartDate != null ? dateFormat.format(a.hawlStartDate!) : '-';
        final daysElapsed = a.hawlStartDate != null ? DateTime.now().difference(a.hawlStartDate!).inDays : 0;
        final isHawlElapsed = a.hawlStartDate != null && daysElapsed >= 354;
        final hawlStatus = isHawlElapsed ? 'Yes (Due Now)' : 'Pending';
        final karatStr = a.purityKarat?.toString() ?? '-';
        buffer.writeln(
          '"${a.name}","${a.assetType}","$karatStr","${a.weightGrams ?? 0}",${a.cashValue.toStringAsFixed(2)},${a.deductibleLiabilities.toStringAsFixed(2)},${a.netZakatableValue.toStringAsFixed(2)},"$hawlDateStr","$hawlStatus"',
        );
      }

      buffer.writeln('');
      buffer.writeln('--- Zakat Disbursement Ledger ---');
      buffer.writeln('Date,Recipient / Charity,Amount,Currency,Notes');

      for (final p in payments) {
        final pDate = dateFormat.format(p.paymentDate);
        final notes = (p.note ?? '').replaceAll('"', '""');
        final recipient = (p.recipient ?? 'Unspecified Recipient').replaceAll('"', '""');
        buffer.writeln(
          '"$pDate","$recipient",${p.amount.toStringAsFixed(2)},"$currency","$notes"',
        );
      }
    }

    return buffer.toString();
  }

  /// Exports and shares CSV content via native platform share dialog
  Future<void> shareCsv({
    required String csvContent,
    required String filename,
    required String subject,
  }) async {
    try {
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsString(csvContent, flush: true);
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv')],
          subject: subject,
        );
        return;
      }
    } catch (e) {
      debugPrint('[ExportService] ShareXFiles failed, falling back to direct share: $e');
    }

    // Direct text fallback
    // ignore: deprecated_member_use
    await Share.share(csvContent, subject: subject);
  }
}
