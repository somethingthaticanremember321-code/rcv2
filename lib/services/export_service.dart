import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';

class ExportService {
  Future<void> exportReceiptsToCSV() async {
    final receipts = DatabaseService().getAllReceipts();

    // Map to CSV rows
    List<List<dynamic>> rows = [
      ['Date', 'Vendor', 'Category', 'Tax', 'Total'] // Header row
    ];

    for (var receipt in receipts) {
      if (receipt.syncStatus == 'failed') continue; // Don't export failed, unsaved parses
      
      String dateStr = '';
      if (receipt.date != null) {
        dateStr = "${receipt.date!.year}-${receipt.date!.month.toString().padLeft(2, '0')}-${receipt.date!.day.toString().padLeft(2, '0')}";
      }

      rows.add([
        dateStr,
        receipt.vendorName ?? 'Unknown',
        receipt.category ?? 'Uncategorized',
        receipt.taxAmount?.toStringAsFixed(2) ?? '0.00',
        receipt.totalAmount?.toStringAsFixed(2) ?? '0.00',
      ]);
    }

    String csvData = csv.encode(rows);

    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/receipts_export_${DateTime.now().millisecondsSinceEpoch}.csv";
    final File file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles(
      [XFile(path)],
      text: 'Here is your receipt export!',
    );
  }
}
