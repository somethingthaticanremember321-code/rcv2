import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/receipt.dart';

abstract class ScanResult {}
class ScanSuccess extends ScanResult {
  final Receipt receipt;
  ScanSuccess(this.receipt);
}
class ScanFailure extends ScanResult {
  final String reason;
  ScanFailure(this.reason);
}

class AiScannerService {
  static const _deepSeekApiKey = 'sk-5aa5c52cd9bc4290bcd39d3ab992f402';
  
  Future<ScanResult> parseReceipt(List<String> imagePaths) async {
    try {
      if (imagePaths.isEmpty) return ScanFailure('no_images');

      // 1. Local OCR with ML Kit with Spatial Row Sorting
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      StringBuffer rawTextBuffer = StringBuffer();
      
      for (String path in imagePaths) {
        final inputImage = InputImage.fromFilePath(path);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        // Collect all lines across blocks to sort spatially
        final List<TextLine> allLines = [];
        for (final block in recognizedText.blocks) {
          allLines.addAll(block.lines);
        }

        // Sort top-to-bottom, grouping horizontal lines within ~14px band
        allLines.sort((a, b) {
          final topDiff = (a.boundingBox.top - b.boundingBox.top).abs();
          if (topDiff < 14) {
            return a.boundingBox.left.compareTo(b.boundingBox.left);
          }
          return a.boundingBox.top.compareTo(b.boundingBox.top);
        });

        for (final line in allLines) {
          rawTextBuffer.writeln(line.text);
        }
        rawTextBuffer.writeln("--- NEXT PAGE ---");
      }
      textRecognizer.close();

      final String rawText = rawTextBuffer.toString();

      if (rawText.trim().isEmpty || rawText.trim().length < 5) {
        return ScanFailure('no_text_found');
      }

      // 2. Structured Parsing Call
      final uri = Uri.parse('https://api.deepseek.com/chat/completions');
      
      final prompt = '''
You are a strict accounting OCR extraction engine. Extract data from the following receipt text.
Note: Text was scanned from physical receipts and may have OCR artifacts (e.g. '1B.50' instead of '18.50', 'O' instead of '0', 'T0TAL' instead of 'TOTAL'). Correct obvious digit confusions for monetary figures.
Return ONLY raw JSON, no markdown formatting, no backticks, no conversational text.
Keys:
- vendorName (string or null): name of the merchant/store
- date (YYYY-MM-DD or null): transaction date
- totalAmount (number or null): final total charged
- taxAmount (number or null): sales tax amount, or null if not listed
- category (one of: Meals, Travel, Software, Office, Utilities, Other)

Receipt text:
$rawText
''';

      var response = await _callDeepSeekWithRetry(uri, prompt);

      if (response == null || response.statusCode != 200) {
        return ScanFailure('server_error');
      }

      // 3. Parse Response
      final responseBody = jsonDecode(response.body);
      final content = responseBody['choices'][0]['message']['content'].toString().trim();
      
      String cleanedContent = content;
      if (cleanedContent.startsWith('```json')) {
        cleanedContent = cleanedContent.substring(7);
      } else if (cleanedContent.startsWith('```')) {
        cleanedContent = cleanedContent.substring(3);
      }
      if (cleanedContent.endsWith('```')) {
        cleanedContent = cleanedContent.substring(0, cleanedContent.length - 3);
      }
      cleanedContent = cleanedContent.trim();
      
      final parsedJson = jsonDecode(cleanedContent);
      
      // Safely parse amounts
      double? totalAmount;
      if (parsedJson['totalAmount'] != null) {
         totalAmount = double.tryParse(parsedJson['totalAmount'].toString());
      }
      
      double? taxAmount;
      if (parsedJson['taxAmount'] != null) {
         taxAmount = double.tryParse(parsedJson['taxAmount'].toString());
      }
      
      DateTime? date;
      if (parsedJson['date'] != null) {
         date = DateTime.tryParse(parsedJson['date'].toString());
      }

      final receipt = Receipt(
        localImagePath: imagePaths.first,
        vendorName: parsedJson['vendorName']?.toString(),
        totalAmount: totalAmount,
        taxAmount: taxAmount,
        date: date,
        category: parsedJson['category']?.toString(),
        syncStatus: 'saved',
      );

      return ScanSuccess(receipt);
    } catch (e) {
      return ScanFailure('parse_error');
    }
  }

  Future<String> askAssistant(String query, List<Receipt> ledger) async {
    try {
      final uri = Uri.parse('https://api.deepseek.com/chat/completions');
      
      final ledgerJson = ledger.where((r) => r.vendorName != null).map((r) => {
        'vendorName': r.vendorName,
        'amount': r.totalAmount,
        'date': r.date?.toIso8601String().split('T').first,
        'category': r.category,
      }).toList();

      final prompt = '''
You are a helpful, professional, and slightly witty AI Financial Assistant.
The user is a trade contractor using the DashTally app.
Answer the user's question accurately based ONLY on the following receipt data.
If the data doesn't contain the answer, say you don't know. Keep responses concise but conversational.

User Ledger Data (JSON):
\n${jsonEncode(ledgerJson)}\n

User Question: "$query"
''';

      var response = await _callDeepSeekWithRetry(uri, prompt);
      
      if (response == null || response.statusCode != 200) {
        return "I'm having trouble connecting to the network right now. Try again in a moment!";
      }

      final responseBody = jsonDecode(response.body);
      return responseBody['choices'][0]['message']['content'].toString().trim();
    } catch (e) {
      return "Oops, something went wrong while analyzing your ledger.";
    }
  }

  Future<http.Response?> _callDeepSeekWithRetry(Uri uri, String prompt) async {
    const maxRetries = 2;
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_deepSeekApiKey',
          },
          body: jsonEncode({
            'model': 'deepseek-chat',
            'messages': [
              {'role': 'system', 'content': 'You are a helpful assistant.'},
              {'role': 'user', 'content': prompt}
            ],
            'temperature': 0.1,
          }),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode >= 500) {
           attempt++;
           await Future.delayed(Duration(seconds: 2 * attempt));
           continue;
        }
        
        return response;
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) return null;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
    return null;
  }
}
