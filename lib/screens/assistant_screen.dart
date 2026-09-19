import 'package:flutter/material.dart';
import '../services/ai_scanner_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Message {
  final String text;
  final bool isUser;
  _Message(this.text, this.isUser);
}

class _AssistantScreenState extends State<AssistantScreen> {
  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  final List<String> _suggestedPrompts = [
    "What are my top tax write-offs?",
    "Summarize my total spending",
    "How much did I spend on meals?",
  ];

  @override
  void initState() {
    super.initState();
    final ledger = _dbService.getAllReceipts();
    if (ledger.isNotEmpty) {
      _messages.add(
        _Message(
          "Hello. I've analyzed your ${ledger.length} local receipt records. Ask me anything about your business deductions, categories, or totals.",
          false,
        ),
      );
    }
  }

  Future<void> _sendQuery(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(_Message(query, true));
      _isLoading = true;
    });
    _controller.clear();

    final ledger = _dbService.getAllReceipts();
    final response = await AiScannerService().askAssistant(query, ledger);

    if (mounted) {
      setState(() {
        _messages.add(_Message(response, false));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _dbService.getAllReceipts();

    if (ledger.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return Align(
                alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: msg.isUser ? AppTheme.pinePrimary : AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(14).copyWith(
                      bottomRight: msg.isUser ? const Radius.circular(2) : const Radius.circular(14),
                      bottomLeft: !msg.isUser ? const Radius.circular(2) : const Radius.circular(14),
                    ),
                    border: msg.isUser ? null : Border.all(color: AppTheme.surfaceBorder),
                    boxShadow: [
                      if (!msg.isUser)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                    ],
                  ),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  child: Text(
                    msg.text,
                    style: AppTheme.body.copyWith(
                      color: msg.isUser ? Colors.white : AppTheme.inkPrimary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: AppTheme.pinePrimary, strokeWidth: 2),
            ),
          ),
        
        // Suggestion chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: _suggestedPrompts.map((prompt) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Pressable(
                  onTap: _isLoading ? null : () => _sendQuery(prompt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: Text(
                      prompt,
                      style: AppTheme.tagText.copyWith(color: AppTheme.inkSecondary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.paperBg,
            border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: AppTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: "Ask about your expenses...",
                      hintStyle: AppTheme.body.copyWith(color: AppTheme.inkMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.pinePrimary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onSubmitted: (text) => _sendQuery(text),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: () => _sendQuery(_controller.text),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.pinePrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.pineLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.pineBorder),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.pinePrimary, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              "AI Expense Assistant",
              style: AppTheme.editorialHeading.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              "Answers tax deduction queries, calculates write-offs, and breaks down expense categories directly from your local ledger.",
              textAlign: TextAlign.center,
              style: AppTheme.body,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "EXAMPLE INQUIRIES",
                    style: AppTheme.sectionHeading,
                  ),
                  const SizedBox(height: 10),
                  Text("• \"What are my highest expenses this month?\"", style: AppTheme.body.copyWith(color: AppTheme.inkPrimary)),
                  const SizedBox(height: 6),
                  Text("• \"Which purchases qualify for tax write-offs?\"", style: AppTheme.body.copyWith(color: AppTheme.inkPrimary)),
                  const SizedBox(height: 6),
                  Text("• \"How much did I spend on software subscriptions?\"", style: AppTheme.body.copyWith(color: AppTheme.inkPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Scan or enter your first receipt to start consulting the assistant.",
              textAlign: TextAlign.center,
              style: AppTheme.tagText.copyWith(color: AppTheme.pinePrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
