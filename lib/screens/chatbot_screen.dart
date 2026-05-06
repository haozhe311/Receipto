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

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
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
        text: 'Hi! I\'m your Receipto financial assistant.\n\n'
            'I have access to your **full transaction history** — yearly summaries, '
            'monthly breakdowns, and your latest 50 transactions.\n\n'
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
        provider: settings.aiProvider,
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
            text: 'Could not reach the AI service. '
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
        ? const Color(0xFF3D1010)
        : isUser
            ? AppTheme.goldDark
            : AppTheme.surface;
    final textColor = message.isError
        ? const Color(0xFFFF9999)
        : isUser
            ? AppTheme.gold
            : AppTheme.textPrimary;
    final borderColor = message.isError
        ? const Color(0xFF6B2020)
        : isUser
            ? AppTheme.gold
            : AppTheme.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
/// - Blank lines as paragraph breaks
class _MarkdownText extends StatelessWidget {
  final String text;
  final Color color;

  const _MarkdownText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        // Blank line → small gap between paragraphs
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      final isBullet = line.startsWith('- ') || line.startsWith('* ');
      final content  = isBullet ? line.substring(2) : line;

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
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
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
        spans.add(TextSpan(
          text: line.substring(cursor, match.start),
          style: TextStyle(color: defaultColor),
        ));
      }

      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: defaultColor,
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (match.group(2) != null) {
        // *italic*
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            color: defaultColor,
            fontStyle: FontStyle.italic,
          ),
        ));
      }

      cursor = match.end;
    }

    // Remaining plain text
    if (cursor < line.length) {
      spans.add(TextSpan(
        text: line.substring(cursor),
        style: TextStyle(color: defaultColor),
      ));
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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.navBar,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Ask about your spending...',
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
      ),
    );
  }
}
