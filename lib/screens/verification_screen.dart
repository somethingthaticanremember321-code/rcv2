import 'dart:io';
import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';

class VerificationScreen extends StatefulWidget {
  final Receipt receipt;

  const VerificationScreen({super.key, required this.receipt});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late TextEditingController _vendorCtrl;
  late TextEditingController _totalCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _dateCtrl;
  String? _selectedCategory;
  late bool _isExisting;

  final List<String> _categories = [
    'Meals', 'Travel', 'Software', 'Office', 'Utilities', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _isExisting = widget.receipt.syncStatus == 'saved';
    _vendorCtrl = TextEditingController(text: widget.receipt.vendorName ?? '');
    _totalCtrl = TextEditingController(text: widget.receipt.totalAmount?.toStringAsFixed(2) ?? '');
    _taxCtrl = TextEditingController(text: widget.receipt.taxAmount?.toStringAsFixed(2) ?? '');
    
    String dateStr = '';
    if (widget.receipt.date != null) {
      dateStr = "${widget.receipt.date!.year}-${widget.receipt.date!.month.toString().padLeft(2, '0')}-${widget.receipt.date!.day.toString().padLeft(2, '0')}";
    } else {
      final now = DateTime.now();
      dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    }
    _dateCtrl = TextEditingController(text: dateStr);
    
    if (_categories.contains(widget.receipt.category)) {
      _selectedCategory = widget.receipt.category;
    } else {
      _selectedCategory = 'Office';
    }
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _totalCtrl.dispose();
    _taxCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    final originalVendor = widget.receipt.vendorName;
    final originalTotal = widget.receipt.totalAmount;

    widget.receipt.vendorName = _vendorCtrl.text.trim().isEmpty ? null : _vendorCtrl.text.trim();
    widget.receipt.totalAmount = double.tryParse(_totalCtrl.text.trim().replaceAll('\$', ''));
    widget.receipt.taxAmount = double.tryParse(_taxCtrl.text.trim().replaceAll('\$', ''));
    widget.receipt.date = DateTime.tryParse(_dateCtrl.text.trim());
    widget.receipt.category = _selectedCategory;
    widget.receipt.syncStatus = 'saved';

    int editedCount = 0;
    if (originalVendor != widget.receipt.vendorName) editedCount++;
    if (originalTotal != widget.receipt.totalAmount) editedCount++;

    final isFirst = DatabaseService().getReceiptCount() == 0;
    await DatabaseService().saveReceipt(widget.receipt);

    AnalyticsService().receiptVerified(
      editedFieldsCount: editedCount,
      wasManual: widget.receipt.localImagePath.isEmpty,
    );
    AnalyticsService().receiptSaved(
      category: widget.receipt.category ?? 'Other',
      isFirstReceipt: isFirst,
      amount: widget.receipt.totalAmount,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.paperBg,
        title: Text('Delete Receipt?', style: AppTheme.editorialHeading.copyWith(fontSize: 18)),
        content: Text(
          'This will permanently remove this record from your ledger. This action cannot be undone.',
          style: AppTheme.body.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTheme.body.copyWith(color: AppTheme.inkSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().deleteReceipt(widget.receipt.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    bool isMissingFromAI, {
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTheme.tagText.copyWith(color: AppTheme.inkSecondary, fontWeight: FontWeight.w600)),
              if (isMissingFromAI) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.ochreLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AI unreadable',
                    style: AppTheme.tagText.copyWith(color: AppTheme.ochreAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: type,
            style: AppTheme.bodyMedium.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: isMissingFromAI ? 'Tap to enter $label' : null,
              hintStyle: AppTheme.body.copyWith(color: AppTheme.inkMuted),
              filled: true,
              fillColor: isMissingFromAI ? AppTheme.ochreLight.withValues(alpha: 0.3) : AppTheme.surfaceCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isMissingFromAI ? AppTheme.ochreAccent : AppTheme.surfaceBorder,
                  width: isMissingFromAI ? 1.4 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.pinePrimary,
                  width: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isManual = widget.receipt.localImagePath.isEmpty;
    final fileExists = !isManual && File(widget.receipt.localImagePath).existsSync();

    return Scaffold(
      backgroundColor: AppTheme.paperBg,
      appBar: AppBar(
        title: Text(_isExisting ? 'Receipt Details' : (isManual ? 'Manual Entry' : 'Verify Receipt'), style: AppTheme.brandTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _save,
              child: Text(
                'Save',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.pinePrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Image Preview with Interactive Pinch-to-Zoom (Top Half)
          if (!isManual)
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFF1C1917), // Dark slate backdrop for high receipt contrast
                width: double.infinity,
                child: Stack(
                  children: [
                    if (fileExists)
                      InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.file(
                            File(widget.receipt.localImagePath),
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Text('Image preview not available', style: TextStyle(color: Colors.white54)),
                      ),
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pinch_rounded, color: Colors.white70, size: 14),
                            SizedBox(width: 4),
                            Text('Pinch to zoom', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Bottom half: Precision Form
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField('Vendor / Merchant', _vendorCtrl, widget.receipt.vendorName == null),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Total Amount (\$)',
                          _totalCtrl,
                          widget.receipt.totalAmount == null,
                          type: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildTextField(
                          'Tax Amount (\$)',
                          _taxCtrl,
                          widget.receipt.taxAmount == null,
                          type: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  _buildTextField('Date (YYYY-MM-DD)', _dateCtrl, widget.receipt.date == null),

                  // Category Dropdown
                  Text('Category', style: AppTheme.tagText.copyWith(color: AppTheme.inkSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.inkSecondary),
                        items: _categories.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: AppTheme.bodyMedium.copyWith(fontSize: 15)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        },
                      ),
                    ),
                  ),

                  if (_isExisting) ...[
                    const SizedBox(height: 28),
                    Pressable(
                      onTap: _deleteReceipt,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.terracottaLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline_rounded, color: AppTheme.terracotta, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Delete Receipt',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.terracotta,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
