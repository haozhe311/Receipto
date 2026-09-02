import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:receipto/services/database_helper.dart';
import 'package:receipto/services/receipt_data.dart';

/// Classifies the user's query so only relevant data is injected.
enum QueryType { yearly, yearlyMonth, monthly, recent, general }

/// One prior turn in the conversation, passed into [AiService.chat] so
/// follow-up questions ("if I cut X, can I still afford it?") can refer back
/// to something said earlier without repeating it.
class ChatTurn {
  final bool isUser;
  final String content;
  const ChatTurn({required this.isUser, required this.content});
}

/// Service for calling Groq's API — chat and receipt-scanning vision alike.
/// Groq is the app's only AI provider (BYOK).
///
/// Chat uses smart context selection: classifies the query with keyword
/// matching then injects only the data level(s) needed, minimising token
/// usage.
class AiService {
  AiService._();

  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Vision-capable Groq model used for receipt/screenshot scanning.
  /// Fixed (not user-selectable) — the text chat model is chosen separately
  /// in Settings.
  static const String groqVisionModel = 'qwen/qwen3.6-27b';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Only the most recent turns are sent back to the model — the system
  /// prompt already re-sends the full financial data dump on every call, so
  /// an unbounded transcript would grow token usage without much benefit
  /// (older turns rarely matter once a follow-up has been answered).
  static const int _maxHistoryTurns = 8; // 4 user/assistant exchanges

  /// Completion budget per chat call. Groq's free/on-demand tier enforces an
  /// 8,000 token-per-minute (TPM) cap across the ENTIRE request — prompt and
  /// completion tokens combined, not prompt alone. The system prompt already
  /// asks for concise answers (1–3 sentences, small tables), so 2048 leaves
  /// comfortable room for that while keeping most of the 8k budget free for
  /// the injected financial data below.
  static const int _maxCompletionTokens = 2048;

  static Future<String> chat({
    required String userMessage,
    required String apiKey,
    String groqModel = 'openai/gpt-oss-120b',
    List<ChatTurn> history = const [],
  }) async {
    final recentHistory = history.length > _maxHistoryTurns
        ? history.sublist(history.length - _maxHistoryTurns)
        : history;

    final queryType = _classifyQuery(userMessage);
    final historyChars =
        recentHistory.fold<int>(0, (sum, t) => sum + t.content.length);
    final systemPrompt = await _buildSystemPrompt(
      userMessage,
      queryType,
      extraChars: historyChars,
    );

    return _callOpenAiCompatible(
      endpoint: _groqEndpoint,
      model: groqModel,
      systemPrompt: systemPrompt,
      history: recentHistory,
      userMessage: userMessage,
      apiKey: apiKey,
      providerName: 'Groq',
    );
  }

  // ---------------------------------------------------------------------------
  // AI receipt parsing (Groq Vision)
  // ---------------------------------------------------------------------------

  /// Sends a receipt/screenshot photo directly to Groq's vision model and
  /// returns the structured [ReceiptData] it extracts. Returns null on any
  /// failure (network error, malformed response) — the caller should surface
  /// that to the user, since there is no on-device OCR fallback.
  ///
  /// Handles both machine-printed receipts (including ones mixing English and
  /// Chinese) and digital bank-transfer/e-wallet screenshots — the model reads
  /// the image directly, so no separate OCR/script configuration is needed.
  static Future<ReceiptData?> parseReceiptFromImage({
    required Uint8List imageBytes,
    required String apiKey,
    List<String> categoryOptions = const [],
  }) async {
    final categoryRule = categoryOptions.isEmpty
        ? '"category" is always null. '
        : '"category" MUST be exactly one of this list (or null if none fits): '
            '${categoryOptions.join(', ')}. Pick the best fit for what was '
            'bought (e.g. a petrol station → Fuel, a restaurant meal → the '
            'closest of Breakfast/Lunch/Dinner, a supermarket → Groceries). ';

    final system =
        'You extract structured transaction data from a photo of either (a) a '
        'machine-printed retail receipt — often in Malaysia, sometimes mixing '
        'English and Chinese text — or (b) a digital bank-transfer / e-wallet '
        'payment screenshot (e.g. DuitNow, Touch \'n Go, Maybank, GrabPay). '
        'Read whichever kind of image this is directly; do not guess if the '
        'text is unclear. '
        'Reply with ONLY minified JSON, no markdown fences and no commentary, '
        'of exactly this shape: '
        '{"merchant":string|null,"date":"YYYY-MM-DD"|null,"total":number|null,'
        '"service_charge_percent":number,"sst_percent":number,'
        '"category":string|null,'
        '"items":[{"name":string,"unit_price":number,"qty":number}]}. '
        'Required fields: merchant, date, and total — extract these from '
        'whichever image type you are given. For a receipt, merchant is the '
        'shop name near the top and total is the final amount payable '
        '(grand/nett total). For a bank-transfer screenshot, merchant is the '
        'recipient/payee name and total is the transferred amount; leave '
        '"items" empty for screenshots (there are no line items). '
        'For receipts, an item name and its price are often on separate '
        'lines — pair them; unit_price is the per-unit price and qty its '
        'quantity. Exclude non-item lines (barcodes, subtotals, totals, tax, '
        'rounding, payment, points, card, phone). Use 0 for a missing '
        'percentage. All numbers are plain, without "RM". $categoryRule';

    final b64 = base64Encode(imageBytes);
    final body = jsonEncode({
      'model': groqVisionModel,
      'messages': [
        {'role': 'system', 'content': system},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': 'Extract the transaction details from this image.',
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$b64'},
            },
          ],
        },
      ],
      'response_format': {'type': 'json_object'},
      'max_tokens': 1200,
      'temperature': 0.2,
    });

    String raw;
    try {
      final response = await _postWithRetry(
        Uri.parse(_groqEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw AiException(
          'Groq API error (${response.statusCode}): '
          '${_extractErrorMessage(response.body)}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw AiException('Groq returned no response choices.');
      }
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null) {
        throw AiException('Groq response format unexpected.');
      }
      raw = content.trim();
    } catch (e) {
      debugPrint('[AiService] Vision receipt parse call failed: $e');
      return null;
    }

    return _receiptFromResponse(raw, raw, categoryOptions);
  }

  static ReceiptData? _receiptFromResponse(
    String response,
    String rawText, [
    List<String> categoryOptions = const [],
  ]) {
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

      // Accept the model's category only if it matches an allowed option
      // (case-insensitive); otherwise fall back to the keyword guesser.
      final rawCategory = map['category']?.toString().trim();
      String? category;
      if (rawCategory != null && rawCategory.isNotEmpty) {
        for (final opt in categoryOptions) {
          if (opt.toLowerCase() == rawCategory.toLowerCase()) {
            category = opt;
            break;
          }
        }
      }
      category ??= ReceiptCategoryGuesser.guessCategory(merchant, items: items);

      return ReceiptData(
        merchant: (merchant != null && merchant.isNotEmpty) ? merchant : null,
        amount: asNum(map['total']),
        date: (dateStr != null && dateStr.isNotEmpty)
            ? DateTime.tryParse(dateStr)
            : null,
        items: items,
        serviceRate: asNum(map['service_charge_percent']),
        taxRate: asNum(map['sst_percent']),
        category: category,
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

    // References an actual specific month (a name, or "this/last month").
    const namedMonthKeywords = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
      'last month', 'this month', 'next month',
      'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug',
      'sep', 'oct', 'nov', 'dec',
    ];
    // Hints at wanting monthly-level granularity without naming a specific
    // month (e.g. "compare" also fires on pure year-vs-year comparisons —
    // it must NOT by itself force the month-level data path).
    const genericMonthHintKeywords = ['bulan', 'monthly', 'trend', 'compare'];

    const yearKeywords = [
      'last year', 'this year', 'next year', 'yearly', 'annual',
      'per year', 'tahun',
    ];
    // Any bare 4-digit year (2024, 2027, ...) also counts — catches future
    // years without needing this list hand-updated every year.
    final hasLiteralYear = RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(q);

    const recentKeywords = [
      'recent', 'latest', 'last few', 'today', 'yesterday',
      'this week', 'minggu', 'semalam', 'tadi', 'baru',
    ];

    final hasNamedMonth = namedMonthKeywords.any((k) => q.contains(k));
    final hasMonthHint = hasNamedMonth ||
        genericMonthHintKeywords.any((k) => q.contains(k));
    final hasYear   = hasLiteralYear || yearKeywords.any((k) => q.contains(k));
    final hasRecent = recentKeywords.any((k) => q.contains(k));

    // Recent-only → recent transactions
    if (hasRecent && !hasMonthHint && !hasYear) return QueryType.recent;

    // A specific month named alongside a year (e.g. "last year July",
    // "January 2025") needs month-level detail within that year.
    if (hasYear && hasNamedMonth) return QueryType.yearlyMonth;

    // Year-level only — including year + a generic word like "compare"/
    // "trend" with no month actually named (e.g. "this year vs last year").
    // yearly_summary covers the FULL history with no size trim, so it's both
    // the more complete and the cheaper answer — deliberately checked before
    // the month-hint branch below so a bare "compare" doesn't misroute a
    // year comparison into the (trimmable) monthly path.
    if (hasYear) return QueryType.yearly;

    // Month-level detail requested without pinning to a specific year.
    if (hasMonthHint) return QueryType.monthly;

    // Default → yearly + last 3 months
    return QueryType.general;
  }

  // ---------------------------------------------------------------------------
  // Context building
  // ---------------------------------------------------------------------------

  static Future<String> _buildSystemPrompt(
    String userMessage,
    QueryType queryType, {
    int extraChars = 0,
  }) async {
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
    // Matches the "latest 50 transactions" promised in the chatbot's welcome
    // message. Falls back to 15 below if the resulting prompt is too large.
    int recentLimit = 50;

    switch (queryType) {
      case QueryType.yearly:
        final results = await Future.wait([
          db.getYearlySummary(),
          db.getYearlyIncomeTotals(),
        ]);
        final yearlyIncome = _toAmountMap(results[1], 'year');
        injectedDataSection = 'yearly_summary:\n'
            '${encoder.convert(_groupYearly(results[0], yearlyIncome))}';
        dataDescription = 'yearly summaries (expenses by category, plus '
            'income/net per year) only';

      case QueryType.yearlyMonth:
        // Month-within-year queries — monthly_summary covers all months.
        final results = await Future.wait([
          db.getMonthlySummary(),
          db.getMonthlyIncomeTotals(),
        ]);
        final monthlyIncome = _toAmountMap(results[1], 'month');
        injectedDataSection = 'monthly_summary:\n'
            '${encoder.convert(_groupMonthlyCompact(results[0], monthlyIncome))}';
        dataDescription = 'monthly summaries (expenses by category, plus '
            'income/net per month, all months, compact)';

      case QueryType.monthly:
        final results = await Future.wait([
          db.getMonthlySummary(),
          db.getMonthlyIncomeTotals(),
        ]);
        final monthlyIncome = _toAmountMap(results[1], 'month');
        injectedDataSection = 'monthly_summary:\n'
            '${encoder.convert(_groupMonthlyCompact(results[0], monthlyIncome))}';
        dataDescription = 'monthly summaries (expenses by category, plus '
            'income/net per month, all months, compact)';

      case QueryType.recent:
        final recentTxns = await db.getRecentTransactions(recentLimit);
        injectedDataSection =
            'recent_transactions (last $recentLimit):\n'
            '${encoder.convert(recentTxns.map((t) => t.toCompactMap()).toList())}';
        dataDescription = 'recent transactions (last $recentLimit), '
            'including any income entries';

      case QueryType.general:
        final generalResults = await Future.wait([
          db.getYearlySummary(),
          db.getMonthlySummary(),
          db.getYearlyIncomeTotals(),
          db.getMonthlyIncomeTotals(),
        ]);
        final yearlyIncome  = _toAmountMap(generalResults[2], 'year');
        final monthlyIncome = _toAmountMap(generalResults[3], 'month');
        final allMonths =
            _groupMonthlyCompact(generalResults[1], monthlyIncome);
        final last3Months = allMonths.take(3).toList();
        injectedDataSection = 'yearly_summary:\n'
            '${encoder.convert(_groupYearly(generalResults[0], yearlyIncome))}'
            '\n\nrecent_months_summary (last 3 months):\n'
            '${encoder.convert(last3Months)}';
        dataDescription = 'yearly summaries and last 3 months summary '
            '(expenses by category, plus income/net per period)';
    }

    // ── Token guard ───────────────────────────────────────────────────────────
    // Groq's on-demand tier enforces an 8,000 TPM cap across prompt +
    // completion tokens TOGETHER, so the prompt's own budget is what's left
    // after reserving _maxCompletionTokens (plus a safety margin, since the
    // char-based estimate below is approximate). Getting this budget wrong
    // in either direction is exactly what let requests silently exceed
    // Groq's real limit despite this guard "passing" — see the 413 errors
    // this was tuned to catch.
    const groqTpmBudget = 8000;
    // Covers two things the char-count below does NOT measure: (a) the
    // static RULES block returned at the end of this method (~2,900 chars /
    // ~900 tokens on its own, present in every call but outside
    // `promptDraft`), and (b) general slack for the char/token ratio being
    // an approximation rather than the model's real tokenizer.
    const estimationSafetyMargin = 1500;
    final promptTokenBudget =
        groqTpmBudget - _maxCompletionTokens - estimationSafetyMargin;

    final promptDraft =
        'data_overview:\n$overviewJson\n\n$injectedDataSection';
    // 3.3 chars/token, not the more typical ~4 — this payload is dense JSON
    // (quotes, braces, digits), which tokenizes more heavily than prose, so
    // a prose-tuned ratio underestimates it.
    final estimatedTokens =
        ((promptDraft.length + userMessage.length + extraChars) / 3.3).ceil();

    if (estimatedTokens > promptTokenBudget) {
      // First trim: cut recent list to 15 if this is a recent query.
      if (queryType == QueryType.recent) {
        debugPrint(
          '[AiService] Token guard triggered ($estimatedTokens est. > '
          '$promptTokenBudget budget). '
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
          '[AiService] Token guard triggered ($estimatedTokens est. > '
          '$promptTokenBudget budget). '
          'Trimming monthly_summary to last 12 months.',
        );
        final results = await Future.wait([
          db.getMonthlySummary(),
          db.getMonthlyIncomeTotals(),
        ]);
        final monthlyIncome = _toAmountMap(results[1], 'month');
        final trimmed =
            _groupMonthlyCompact(results[0], monthlyIncome).take(12).toList();
        injectedDataSection =
            'monthly_summary (last 12 months):\n${encoder.convert(trimmed)}';
        dataDescription = 'monthly summaries (last 12 months, expenses by '
            'category, plus income/net per month, compact)';
      }
    }

    return '''You are Receipto's AI Financial Advisor. You help users understand their personal spending habits.

For this query, you have been provided with: $dataDescription.

RULES:
- Base answers strictly on the provided data only — never hallucinate figures
- Within yearly_summary/monthly_summary, "categories" and "total"/"year_total" are EXPENSES only. Each year/month entry ALSO has "income"/"year_income" and "net"/"year_net" (income minus expenses for that period) — use these for savings-rate, affordability, and "can I afford X by date Y" questions. data_overview's all_time_income is the all-time total across the whole history.
- For savings-projection questions (e.g. "can I save RM X by [date]?"): compute a monthly net-savings rate from recent income/net figures (prefer the last 3–6 months over very old ones if spending has clearly changed), multiply by the number of months until the target date, and compare to the goal. State the rate and the assumption you used (e.g. "assuming your recent ~RM150/month net continues").
- Prefer a best-effort estimate using whatever aggregate data IS available over refusing outright — only say a question can't be answered if truly nothing relevant is provided
- This app does NOT track account balances or savings-goal progress — only income/expense transactions. If asked about current savings/balance, say you can only estimate from cash flow (income minus expenses), not state a real balance as fact
- When user says "last month", refer to: $lastMonth
- When user says "last year", refer to: $lastYear
- When user says "this year", refer to: $currentYear
- Format currency as RM X.XX
- Use markdown: **bold**, *italic*, bullet lists with -
- NEVER use LaTeX/math markup (no \\[ \\], \\( \\), \$\$, \\frac, \\text, \\approx, etc.) — this chat cannot render it and it will show as broken text. Write any calculation in plain text/markdown instead, e.g. "10,000 ÷ 321 ≈ 31 months" or "Months needed = 10,000 ÷ 321 ≈ **31**"
- When user asks about a specific month within a year (e.g. "last year July", "January 2025"), look up that exact month in the monthly_summary using the format YYYY-MM (e.g. "2025-07", "2025-01")
- If a question genuinely cannot be answered from the data provided, say so clearly

BE CONCISE — this is a chat conversation, not a report:
- Answer ONLY what was asked. A number, a short sentence, or a small table is
  often the whole answer — stop there.
- Never restate a table's numbers again as bullet points below it, and vice
  versa — pick ONE format per fact.
- Do NOT add unsolicited sections (e.g. "What this means", "Actionable tips",
  "Recommendations") unless the user's question explicitly asks for advice,
  tips, or suggestions.
- Default length: 1–3 sentences, or a table/list of at most ~5 rows. Only go
  longer if the user's question genuinely requires it (e.g. they asked to
  "compare every month" or "list all categories").

---

data_overview:
$overviewJson

$injectedDataSection''';
  }

  // ---------------------------------------------------------------------------
  // Aggregation helpers
  // ---------------------------------------------------------------------------

  /// [incomeByYear] adds an `income`/`net` figure to each year so the model
  /// can compute a real savings rate — `categories`/`year_total` remain
  /// EXPENSES only (income has no per-category breakdown in this app).
  static List<Map<String, dynamic>> _groupYearly(
    List<Map<String, dynamic>> rows,
    Map<String, double> incomeByYear,
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
    // A year with income but no expenses (rare, but possible) still appears.
    for (final year in incomeByYear.keys) {
      map.putIfAbsent(
        year,
        () => {'year': year, 'categories': <dynamic>[], 'year_total': 0.0},
      );
    }
    for (final entry in map.values) {
      final income = incomeByYear[entry['year']] ?? 0.0;
      entry['year_income'] = _round(income);
      entry['year_net'] = _round(income - (entry['year_total'] as double));
    }
    return map.values.toList();
  }

  /// Compact monthly grouper: month total + all categories (total > 0) as a
  /// flat object map. Omits count to save tokens.
  /// e.g. "categories": {"Food": 891.23, "Transport": 68.18}
  ///
  /// [incomeByMonth] adds `income`/`net` per month (see [_groupYearly] — the
  /// same expense-only convention applies to `categories`/`total` here).
  static List<Map<String, dynamic>> _groupMonthlyCompact(
    List<Map<String, dynamic>> rows,
    Map<String, double> incomeByMonth,
  ) {
    final map = <String, Map<String, dynamic>>{};
    Map<String, dynamic> newMonthEntry(String month) {
      final parts = month.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return {
        'month':      month,
        'label':      DateFormat('MMMM yyyy').format(dt),
        'total':      0.0,
        'categories': <String, double>{},
      };
    }

    for (final row in rows) {
      final month = row['month'] as String;
      map.putIfAbsent(month, () => newMonthEntry(month));
      final amount = _round(row['total']);
      if (amount > 0) {
        (map[month]!['categories'] as Map<String, double>)[row['category'] as String] = amount;
      }
      map[month]!['total'] = _round((map[month]!['total'] as double) + amount);
    }
    for (final month in incomeByMonth.keys) {
      map.putIfAbsent(month, () => newMonthEntry(month));
    }
    for (final entry in map.values) {
      final income = incomeByMonth[entry['month']] ?? 0.0;
      entry['income'] = _round(income);
      entry['net'] = _round(income - (entry['total'] as double));
    }
    return map.values.toList();
  }

  static double _round(dynamic value) {
    if (value == null) return 0.0;
    return double.parse((value as num).toDouble().toStringAsFixed(2));
  }

  /// Converts income-totals rows (each `{key: "2026", total: 123.0}`) into a
  /// lookup map for merging into [_groupYearly]/[_groupMonthlyCompact].
  static Map<String, double> _toAmountMap(
    List<Map<String, dynamic>> rows,
    String key,
  ) {
    return {for (final r in rows) r[key] as String: _round(r['total'])};
  }

  // ---------------------------------------------------------------------------
  // HTTP with 429 retry
  // ---------------------------------------------------------------------------

  /// POSTs [body] to [url], retrying with backoff when the response is
  /// HTTP 429 (Too Many Requests) — vision calls in particular consume a lot
  /// of tokens and are the most likely to hit a free-tier rate limit.
  ///
  /// Honors the provider's `retry-after` header (seconds) when present;
  /// otherwise backs off exponentially (1s, 2s, 4s, 8s, capped at 16s) with a
  /// small random jitter to avoid retry storms. Gives up after [maxRetries]
  /// retries and returns the final (still-429) response so the caller's
  /// normal status-code handling can surface a clear error.
  static Future<http.Response> _postWithRetry(
    Uri url, {
    required Map<String, String> headers,
    required String body,
    int maxRetries = 3,
  }) async {
    var attempt = 0;
    while (true) {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 429 || attempt >= maxRetries) {
        return response;
      }
      final wait = _retryDelay(response, attempt);
      debugPrint(
        '[AiService] 429 rate limited — retrying in ${wait.inMilliseconds}ms '
        '(attempt ${attempt + 1}/$maxRetries)',
      );
      await Future.delayed(wait);
      attempt++;
    }
  }

  static Duration _retryDelay(http.Response response, int attempt) {
    final retryAfter = response.headers['retry-after'];
    if (retryAfter != null) {
      final secs = int.tryParse(retryAfter);
      if (secs != null && secs >= 0) return Duration(seconds: secs);
    }
    final backoffSecs = (1 << attempt).clamp(1, 16); // 1, 2, 4, 8, 16...
    final jitterMs = Random().nextInt(500);
    return Duration(seconds: backoffSecs, milliseconds: jitterMs);
  }

  // ---------------------------------------------------------------------------
  // API callers
  // ---------------------------------------------------------------------------

  static Future<String> _callOpenAiCompatible({
    required String endpoint,
    required String model,
    required String systemPrompt,
    required String userMessage,
    required String apiKey,
    required String providerName,
    List<ChatTurn> history = const [],
  }) async {
    final url = Uri.parse(endpoint);

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        for (final turn in history)
          {'role': turn.isUser ? 'user' : 'assistant', 'content': turn.content},
        {'role': 'user', 'content': userMessage},
      ],
      // See _maxCompletionTokens: this reservation counts against Groq's 8k
      // TPM budget alongside the prompt itself, so it must stay small.
      'max_tokens': _maxCompletionTokens,
      'temperature': 0.7,
    });

    final response = await _postWithRetry(
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
