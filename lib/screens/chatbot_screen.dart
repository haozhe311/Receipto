import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/settings_provider.dart';
import 'package:receipto/services/ai_service.dart';

/// A single message in the chat history.
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  ChatMessage({required this.text, required this.isUser, this.isError = false});
}

/// AI-powered financial chatbot screen.
///
/// Injects yearly summaries, monthly summaries, and recent transactions
/// as structured JSON context on every message so the AI can answer
/// questions across any time range.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text:
            'Hi! I\'m your Receipto financial assistant.\n\n'
            'I have access to your **full transaction history** — yearly summaries, '
            'monthly breakdowns, and your latest transactions (up to 50).\n\n'
            'Try asking:\n'
            '- "How much did I spend last month?"\n'
            '- "Compare my spending this year vs last year"\n'
            '- "Which category do I spend the most on?"',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Financial Advisor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear chat',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const _TypingIndicator();
                }
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),
          _InputBar(
            controller: _inputController,
            isLoading: _isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    final settings = context.read<SettingsProvider>();
    if (!settings.hasApiKey) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Please set your API key in the Settings tab first.',
            isUser: false,
            isError: true,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      final response = await AiService.chat(
        userMessage: text,
        apiKey: settings.apiKey!,
        groqModel: settings.groqModel,
        history: _historyForApi(),
      );

      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
    } on AiException catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(text: e.message, isUser: false, isError: true),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Could not reach the AI service. '
                'Check your API key and internet connection.\n\nError: $e',
            isUser: false,
            isError: true,
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  /// Builds the conversation history to send to the API: every prior
  /// exchange except the static welcome greeting (index 0 — the model never
  /// said that), error messages (not real replies), and the user message
  /// just added to [_messages] (that's sent separately as `userMessage`).
  List<ChatTurn> _historyForApi() {
    if (_messages.length <= 2) return const [];
    final prior = _messages.sublist(1, _messages.length - 1);
    return [
      for (final m in prior)
        if (!m.isError) ChatTurn(isUser: m.isUser, content: m.text),
    ];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          text: 'Chat cleared. Ask me anything about your spending!',
          isUser: false,
        ),
      );
    });
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    final bgColor = message.isError
        ? const Color(0xFFFEE2E2)
        : isUser
        ? AppTheme.goldDark
        : AppTheme.glassRowFill;
    final textColor = message.isError
        ? const Color(0xFFFF9999)
        : isUser
        ? AppTheme.gold
        : AppTheme.textPrimary;
    final borderColor = message.isError
        ? const Color(0xFFFECACA)
        : isUser
        ? AppTheme.gold
        : AppTheme.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                message.isError ? Icons.error_outline : Icons.smart_toy,
                color: Colors.white,
                size: 18,
              ),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(color: borderColor),
              ),
              // User bubbles are plain text; AI bubbles render markdown.
              child: isUser
                  ? SelectableText(
                      message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  : _MarkdownText(text: message.text, color: textColor),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.border,
              child: Icon(Icons.person, color: AppTheme.textPrimary, size: 18),
            ),
        ],
      ),
    );
  }
}

// ── Inline markdown renderer ──────────────────────────────────────────────────

/// Renders a subset of markdown without any external package:
/// - **bold**
/// - *italic*
/// - Lines starting with "- " or "* " as bullet list items
/// - "### Heading" (1–6 leading #s) as a bold section heading
/// - GitHub-style tables (a "| a | b |" row followed by a "|---|---|"
///   separator row) as a real bordered, horizontally-scrollable [Table]
/// - Blank lines as paragraph breaks
class _MarkdownText extends StatelessWidget {
  final String text;
  final Color color;

  const _MarkdownText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        // Blank line → small gap between paragraphs
        widgets.add(const SizedBox(height: 6));
        i++;
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line.trim());
      if (headingMatch != null) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 4),
            child: SelectableText.rich(
              _buildSpan(headingMatch.group(2)!.trim(), color),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // Table: a "| a | b |" row immediately followed by a "|---|---|" rule.
      if (_looksLikeTableRow(line) &&
          i + 1 < lines.length &&
          _looksLikeTableSeparator(lines[i + 1])) {
        final tableLines = [line];
        var j = i + 2;
        while (j < lines.length && _looksLikeTableRow(lines[j])) {
          tableLines.add(lines[j]);
          j++;
        }
        widgets.add(_buildTable(tableLines, color));
        i = j;
        continue;
      }

      final isBullet = line.startsWith('- ') || line.startsWith('* ');
      final content = isBullet ? line.substring(2) : line;

      if (isBullet) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(color: color, fontSize: 14, height: 1.4),
                ),
                Flexible(
                  child: SelectableText.rich(
                    _buildSpan(content, color),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: SelectableText.rich(
              _buildSpan(content, color),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        );
      }
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  // ── Table parsing/rendering ─────────────────────────────────────────────

  static bool _looksLikeTableRow(String line) {
    final t = line.trim();
    return t.startsWith('|') && t.endsWith('|') && t.length > 1;
  }

  static bool _looksLikeTableSeparator(String line) {
    final t = line.trim();
    return t.startsWith('|') &&
        t.contains('-') &&
        RegExp(r'^\|[\s:|-]+\|$').hasMatch(t);
  }

  static List<String> _splitTableRow(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|').map((c) => c.trim()).toList();
  }

  /// Builds a bordered, horizontally-scrollable table from the header row
  /// (tableLines[0]) and data rows (the rest) — the separator row itself was
  /// already consumed by the caller and never appears here.
  static Widget _buildTable(List<String> tableLines, Color color) {
    final header = _splitTableRow(tableLines[0]);
    final rows = tableLines.skip(1).map(_splitTableRow).toList();
    final columnCount = header.length;

    Widget cell(String value, {required bool bold}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: SelectableText.rich(
            _buildSpan(value, color),
            style: TextStyle(
              color: color,
              fontSize: 13,
              height: 1.3,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: color.withValues(alpha: 0.25),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08)),
              children: [
                for (final h in header) cell(h, bold: true),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  for (var c = 0; c < columnCount; c++)
                    cell(c < row.length ? row[c] : '', bold: false),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Parses **bold** and *italic* within a single line into a [TextSpan].
  static TextSpan _buildSpan(String line, Color defaultColor) {
    final spans = <InlineSpan>[];
    // Regex: **bold** | *italic*
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    int cursor = 0;

    for (final match in pattern.allMatches(line)) {
      // Plain text before the match
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: line.substring(cursor, match.start),
            style: TextStyle(color: defaultColor),
          ),
        );
      }

      if (match.group(1) != null) {
        // **bold**
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(color: defaultColor, fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(2) != null) {
        // *italic*
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(color: defaultColor, fontStyle: FontStyle.italic),
          ),
        );
      }

      cursor = match.end;
    }

    // Remaining plain text
    if (cursor < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(cursor),
          style: TextStyle(color: defaultColor),
        ),
      );
    }

    return TextSpan(children: spans);
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.glassRowFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorderSoft),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    // Floating composer that sits just above the floating pill nav (the body
    // extends behind the nav). No full-width bar — a white rounded field on the
    // page, so there's no awkward gap under it.
    // safeBottom already includes the floating-nav clearance (the shell sets it
    // via extendBody), so we must NOT add extra on top of it.
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 6, 12, 10 + safeBottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Ask about your spending...',
                filled: true,
                fillColor: AppTheme.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              enabled: !isLoading,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isLoading ? null : onSend,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
