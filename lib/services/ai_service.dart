import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:receipto/services/database_helper.dart';
import 'package:receipto/services/ocr_service.dart';

/// Classifies the user's query so only relevant data is injected.
enum QueryType { yearly, yearlyMonth, monthly, recent, general }

/// Service for calling AI chat APIs (Google Gemini, OpenAI, or Groq).
///
/// Uses smart context selection: classifies the query with keyword matching
/// then injects only the data level(s) needed, minimising token usage.
class AiService {
  AiService._();

  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent';
  static const String _openAiEndpoint =
      'https://api.openai.com/v1/chat/completions';
  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  static Future<String> chat({
    required String userMessage,
    required String apiKey,
    required String provider,
    String groqModel = 'llama-3.1-8b-instant',
  }) async {
    final queryType = _classifyQuery(userMessage);
    final systemPrompt = await _buildSystemPrompt(userMessage, queryType);

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
        model: groqModel,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        apiKey: apiKey,
        providerName: 'Groq',
      );
    } else {
      throw ArgumentError('Unknown AI provider: $provider');
    }
  }

  // ---------------------------------------------------------------------------
  // AI receipt parsing
  // ---------------------------------------------------------------------------

  /// Uses the LLM to turn raw receipt OCR text into structured [ReceiptData].
  ///
  /// LLMs handle arbitrary receipt layouts far better than regex — including
  /// items whose name and price sit on separate lines. Returns null on any
  /// failure so the caller can fall back to the on-device regex parser.
  static Future<ReceiptData?> parseReceipt({
    required String rawText,
    required String apiKey,
    required String provider,
    String groqModel = 'llama-3.1-8b-instant',
  }) async {
    const system =
        'You extract structured data from Malaysian receipt OCR text. '
        'Reply with ONLY minified JSON, no markdown fences and no commentary, '
        'of exactly this shape: '
        '{"merchant":string|null,"date":"YYYY-MM-DD"|null,"total":number|null,'
        '"service_charge_percent":number,"sst_percent":number,'
        '"items":[{"name":string,"unit_price":number,"qty":number}]}. '
        'Guidance: merchant is the shop name near the top. total is the final '
        'amount payable (grand/nett total). An item name and its price are '
        'often on separate lines — pair them; unit_price is the per-unit price '
        'and qty its quantity. Exclude non-item lines (barcodes, subtotals, '
        'totals, tax, rounding, payment, points, card, phone). Use 0 for a '
        'missing percentage. All numbers are plain, without "RM".';
    final user = 'Receipt OCR text:\n$rawText';

    String raw;
    try {
      if (provider == 'gemini') {
        raw = await _callGemini(
          systemPrompt: system,
          userMessage: user,
          apiKey: apiKey,
        );
      } else if (provider == 'openai') {
        raw = await _callOpenAiCompatible(
          endpoint: _openAiEndpoint,
          model: 'gpt-4o-mini',
          systemPrompt: system,
          userMessage: user,
          apiKey: apiKey,
          providerName: 'OpenAI',
        );
      } else if (provider == 'groq') {
        raw = await _callOpenAiCompatible(
          endpoint: _groqEndpoint,
          model: groqModel,
          systemPrompt: system,
          userMessage: user,
          apiKey: apiKey,
          providerName: 'Groq',
        );
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('[AiService] Receipt parse call failed: $e');
      return null;
    }

    return _receiptFromResponse(raw, rawText);
  }

  static ReceiptData? _receiptFromResponse(String response, String rawText) {
    // Isolate the JSON object even if the model wrapped it in prose/fences.
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start == -1 || end <= start) return null;

    try {
      final map =
          jsonDecode(response.substring(start, end + 1)) as Map<String, dynamic>;

      double? asNum(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.\-]'), ''));
      }

      final items = <ReceiptItem>[];
      for (final raw in (map['items'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final name = (raw['name'] ?? '').toString().trim();
        final price = asNum(raw['unit_price']) ?? 0;
        final qty = (asNum(raw['qty']) ?? 1).round();
        if (name.isEmpty || price <= 0) continue;
        items.add(ReceiptItem(name: name, price: price, qty: qty < 1 ? 1 : qty));
      }

      final merchant = map['merchant']?.toString().trim();
      final dateStr = map['date']?.toString();

      return ReceiptData(
        merchant: (merchant != null && merchant.isNotEmpty) ? merchant : null,
        amount: asNum(map['total']),
        date: (dateStr != null && dateStr.isNotEmpty)
            ? DateTime.tryParse(dateStr)
            : null,
        items: items,
        serviceRate: asNum(map['service_charge_percent']),
        taxRate: asNum(map['sst_percent']),
        rawText: rawText,
        merchantConfidence: OcrConfidence.high,
        amountConfidence: OcrConfidence.high,
        dateConfidence: OcrConfidence.high,
      );
    } catch (e) {
      debugPrint('[AiService] Receipt JSON parse failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Query classification
  // ---------------------------------------------------------------------------

  static QueryType _classifyQuery(String query) {
    final q = query.toLowerCase();

    const monthKeywords = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
      'last month', 'this month', 'bulan', 'monthly',
      'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug',
      'sep', 'oct', 'nov', 'dec',
      'trend', 'compare',
    ];

    const yearKeywords = [
      'last year', 'this year', 'yearly', 'annual',
      'per year', 'tahun', '2024', '2025', '2026',
    ];

    const recentKeywords = [
      'recent', 'latest', 'last few', 'today', 'yesterday',
      'this week', 'minggu', 'semalam', 'tadi', 'baru',
    ];

    final hasMonth  = monthKeywords.any((k) => q.contains(k));
    final hasYear   = yearKeywords.any((k) => q.contains(k));
    final hasRecent = recentKeywords.any((k) => q.contains(k));

    // Recent-only → recent transactions
    if (hasRecent && !hasMonth && !hasYear) return QueryType.recent;

    // Year + Month combined (e.g. "last year July", "2025 March")
    // monthly_summary covers all months so it handles both axes.
    if (hasYear && hasMonth) return QueryType.yearlyMonth;

    // Month only
    if (hasMonth) return QueryType.monthly;

    // Year only (no month mentioned)
    if (hasYear) return QueryType.yearly;

    // Default → yearly + last 3 months
    return QueryType.general;
  }

  // ---------------------------------------------------------------------------
  // Context building
  // ---------------------------------------------------------------------------

  static Future<String> _buildSystemPrompt(
    String userMessage,
    QueryType queryType,
  ) async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    // Always fetch overview — it's cheap (single aggregation row).
    final overviewRow = await db.getDataOverview();

    final currentMonth = DateFormat('MMMM yyyy').format(now);
    final currentYear  = now.year.toString();
    final lastMonth    = DateFormat('MMMM yyyy')
        .format(DateTime(now.year, now.month - 1));
    final lastYear     = (now.year - 1).toString();

    final dataOverview = {
      'total_transactions': overviewRow['total_transactions'],
      'earliest_date':      overviewRow['earliest_date'] ?? 'n/a',
      'latest_date':        overviewRow['latest_date']   ?? 'n/a',
      'all_time_expense':   _round(overviewRow['all_time_total']),
      'all_time_income':    _round(overviewRow['all_time_income']),
      'today':              DateFormat('yyyy-MM-dd').format(now),
      'current_month':      currentMonth,
      'current_year':       currentYear,
      'last_month':         lastMonth,
      'last_year':          lastYear,
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final overviewJson = encoder.convert(dataOverview);

    // ── Fetch only the data level(s) needed ──────────────────────────────────
    String injectedDataSection;
    String dataDescription;
    int recentLimit = 30;

    switch (queryType) {
      case QueryType.yearly:
        final yearlyRows = await db.getYearlySummary();
        injectedDataSection =
            'yearly_summary:\n${encoder.convert(_groupYearly(yearlyRows))}';
        dataDescription = 'yearly summaries only';

      case QueryType.yearlyMonth:
        // Month-within-year queries — monthly_summary covers all months.
        final monthlyRows = await db.getMonthlySummary();
        injectedDataSection =
            'monthly_summary:\n${encoder.convert(_groupMonthlyCompact(monthlyRows))}';
        dataDescription = 'monthly summaries (all months, compact)';

      case QueryType.monthly:
        final monthlyRows = await db.getMonthlySummary();
        injectedDataSection =
            'monthly_summary:\n${encoder.convert(_groupMonthlyCompact(monthlyRows))}';
        dataDescription = 'monthly summaries (all months, compact)';

      case QueryType.recent:
        final recentTxns = await db.getRecentTransactions(recentLimit);
        injectedDataSection =
            'recent_transactions (last $recentLimit):\n'
            '${encoder.convert(recentTxns.map((t) => t.toCompactMap()).toList())}';
        dataDescription = 'recent transactions (last $recentLimit)';

      case QueryType.general:
        final generalResults = await Future.wait([
          db.getYearlySummary(),
          db.getMonthlySummary(),
        ]);
        final allMonths   = _groupMonthlyCompact(generalResults[1]);
        final last3Months = allMonths.take(3).toList();
        injectedDataSection =
            'yearly_summary:\n${encoder.convert(_groupYearly(generalResults[0]))}\n\n'
            'recent_months_summary (last 3 months):\n${encoder.convert(last3Months)}';
        dataDescription = 'yearly summaries and last 3 months summary';
    }

    // ── Token guard ───────────────────────────────────────────────────────────
    final promptDraft =
        'data_overview:\n$overviewJson\n\n$injectedDataSection';
    final estimatedTokens =
        ((promptDraft.length + userMessage.length) / 4).ceil();

    if (estimatedTokens > 5000) {
      // First trim: cut recent list to 15 if this is a recent query.
      if (queryType == QueryType.recent) {
        debugPrint(
          '[AiService] Token guard triggered ($estimatedTokens est.). '
          'Trimming recent_transactions to 15.',
        );
        recentLimit = 15;
        final trimmedTxns = await db.getRecentTransactions(recentLimit);
        injectedDataSection =
            'recent_transactions (last $recentLimit):\n'
            '${encoder.convert(trimmedTxns.map((t) => t.toCompactMap()).toList())}';
      } else if (queryType == QueryType.monthly ||
                 queryType == QueryType.yearlyMonth) {
        // Second trim: cap monthly_summary to last 12 months.
        debugPrint(
          '[AiService] Token guard triggered ($estimatedTokens est.). '
          'Trimming monthly_summary to last 12 months.',
        );
        final monthlyRows = await db.getMonthlySummary();
        final trimmed = _groupMonthlyCompact(monthlyRows).take(12).toList();
        injectedDataSection =
            'monthly_summary (last 12 months):\n${encoder.convert(trimmed)}';
        dataDescription = 'monthly summaries (last 12 months, compact)';
      }
    }

    return '''You are Receipto's AI Financial Advisor. You help users understand their personal spending habits.

For this query, you have been provided with: $dataDescription.

RULES:
- Base answers strictly on the provided data only — never hallucinate figures
- All category and summary spending figures are EXPENSES only; income is tracked separately (see all_time_income in data_overview)
- When user says "last month", refer to: $lastMonth
- When user says "last year", refer to: $lastYear
- When user says "this year", refer to: $currentYear
- Format currency as RM X.XX
- Keep responses concise and actionable
- Use markdown: **bold**, *italic*, bullet lists with -
- When user asks about a specific month within a year (e.g. "last year July", "January 2025"), look up that exact month in the monthly_summary using the format YYYY-MM (e.g. "2025-07", "2025-01")
- If a question cannot be answered from the data provided, say so clearly

---

data_overview:
$overviewJson

$injectedDataSection''';
  }

  // ---------------------------------------------------------------------------
  // Aggregation helpers
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _groupYearly(
    List<Map<String, dynamic>> rows,
  ) {
    final map = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final year = row['year'] as String;
      map.putIfAbsent(
        year,
        () => {'year': year, 'categories': <dynamic>[], 'year_total': 0.0},
      );
      final amount = _round(row['total']);
      (map[year]!['categories'] as List).add({
        'category': row['category'],
        'total':    amount,
        'count':    row['count'],
      });
      map[year]!['year_total'] =
          _round((map[year]!['year_total'] as double) + amount);
    }
    return map.values.toList();
  }

  /// Compact monthly grouper: month total + all categories (total > 0) as a
  /// flat object map. Omits count to save tokens.
  /// e.g. "categories": {"Food": 891.23, "Transport": 68.18}
  static List<Map<String, dynamic>> _groupMonthlyCompact(
    List<Map<String, dynamic>> rows,
  ) {
    final map = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final month = row['month'] as String;
      map.putIfAbsent(month, () {
        final parts = month.split('-');
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        return {
          'month':      month,
          'label':      DateFormat('MMMM yyyy').format(dt),
          'total':      0.0,
          'categories': <String, double>{},
        };
      });
      final amount = _round(row['total']);
      if (amount > 0) {
        (map[month]!['categories'] as Map<String, double>)[row['category'] as String] = amount;
      }
      map[month]!['total'] = _round((map[month]!['total'] as double) + amount);
    }
    return map.values.toList();
  }

  static double _round(dynamic value) {
    if (value == null) return 0.0;
    return double.parse((value as num).toDouble().toStringAsFixed(2));
  }

  // ---------------------------------------------------------------------------
  // API callers
  // ---------------------------------------------------------------------------

  static Future<String> _callGemini({
    required String systemPrompt,
    required String userMessage,
    required String apiKey,
  }) async {
    final url = Uri.parse('$_geminiEndpoint?key=$apiKey');
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
      'max_tokens': 800,
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

  static String _extractErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map) {
        return error['message']?.toString() ?? responseBody;
      } else if (error is String) {
        return error;
      }
    } catch (_) {}
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
