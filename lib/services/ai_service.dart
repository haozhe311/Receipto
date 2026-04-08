import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service for calling AI chat APIs (Google Gemini, OpenAI, or Groq).
///
/// Uses BYOK (Bring Your Own Key) — the user's API key is passed in
/// on each call. Constructs a grounded system prompt using the
/// user's transaction data as context.
class AiService {
  AiService._();

  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent';
  static const String _openAiEndpoint =
      'https://api.openai.com/v1/chat/completions';
  // Groq uses the OpenAI-compatible Chat Completions format.
  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Sends a chat message to the selected AI provider and returns the response.
  ///
  /// [userMessage] is the natural language query from the user.
  /// [transactionContext] is a JSON-encoded array of recent transactions.
  /// [apiKey] is the user's BYOK key.
  /// [provider] must be 'gemini', 'openai', or 'groq'.
  static Future<String> chat({
    required String userMessage,
    required String transactionContext,
    required String apiKey,
    required String provider,
  }) async {
    final systemPrompt = _buildSystemPrompt(transactionContext);

    if (provider == 'gemini') {
      return _callGemini(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        apiKey: apiKey,
      );
    } else if (provider == 'openai') {
      return _callOpenAiCompatible(
        endpoint: _openAiEndpoint,
        model: 'gpt-4o-mini',
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        apiKey: apiKey,
        providerName: 'OpenAI',
      );
    } else if (provider == 'groq') {
      return _callOpenAiCompatible(
        endpoint: _groqEndpoint,
        model: 'llama-3.1-8b-instant',
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        apiKey: apiKey,
        providerName: 'Groq',
      );
    } else {
      throw ArgumentError('Unknown AI provider: $provider');
    }
  }

  /// Constructs the grounded system prompt with transaction context.
  static String _buildSystemPrompt(String transactionContext) {
    final today = DateTime.now().toIso8601String().split('T').first;

    return '''You are Receipto's AI Financial Advisor. Your role is to help the user understand and improve their personal spending habits.

You MUST base ALL your answers strictly on the transaction data provided below. Do NOT invent, assume, or hallucinate any financial figures that are not present in this data.

The user's recent transactions (in JSON format):
$transactionContext

Today's date: $today
Currency: Malaysian Ringgit (RM)

Instructions:
- Answer questions about spending patterns, totals, and trends.
- When summarizing, break down by category with exact amounts.
- Give practical, specific budgeting advice based on actual data.
- Be concise. Use bullet points for lists.
- If the user asks something that cannot be answered from the provided data, say so honestly.
- Respond in the same language the user writes in.''';
  }

  /// Calls the Google Gemini API.
  static Future<String> _callGemini({
    required String systemPrompt,
    required String userMessage,
    required String apiKey,
  }) async {
    final url = Uri.parse('$_geminiEndpoint?key=$apiKey');

    // Gemini doesn't have a separate "system" role — prepend to the user text.
    final fullPrompt = '$systemPrompt\n\nUser question: $userMessage';

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': fullPrompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 800,
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw AiException(
        'Gemini API error (${response.statusCode}): ${_extractErrorMessage(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw AiException('Gemini returned no response candidates.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw AiException('Gemini response format unexpected.');
    }

    return (parts.first['text'] as String).trim();
  }

  /// Calls any OpenAI-compatible Chat Completions endpoint.
  /// Used for both OpenAI and Groq (which share the same API format).
  static Future<String> _callOpenAiCompatible({
    required String endpoint,
    required String model,
    required String systemPrompt,
    required String userMessage,
    required String apiKey,
    required String providerName,
  }) async {
    final url = Uri.parse(endpoint);

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ],
      'max_tokens': 1024,
      'temperature': 0.7,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw AiException(
        '$providerName API error (${response.statusCode}): ${_extractErrorMessage(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw AiException('$providerName returned no response choices.');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) {
      throw AiException('$providerName response format unexpected.');
    }

    return content.trim();
  }

  /// Attempts to extract a human-readable error message from an API error body.
  static String _extractErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map) {
        return error['message']?.toString() ?? responseBody;
      } else if (error is String) {
        return error;
      }
    } catch (_) {
      // Fall through to raw body
    }
    return responseBody.length > 200
        ? '${responseBody.substring(0, 200)}...'
        : responseBody;
  }
}

/// Exception thrown when an AI API call fails.
class AiException implements Exception {
  final String message;
  AiException(this.message);

  @override
  String toString() => message;
}
