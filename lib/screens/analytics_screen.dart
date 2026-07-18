import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/budget_provider.dart';
import 'package:receipto/screens/budgets_screen.dart';
import 'package:receipto/services/database_helper.dart';
import 'package:receipto/services/insight_service.dart';
import 'package:receipto/widgets/budget_widgets.dart';

/// Spending analytics: monthly cash-flow, category breakdown, and a
/// 6-month income/expense trend. Charts are drawn with plain Flutter
/// widgets — no external charting dependency.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const Color _income = Color(0xFF4CAF50);
  static const Color _expenseRed = Color(0xFFFF6B6B);

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;

  double _monthIncome = 0;
  double _monthExpense = 0;
  Map<String, double> _categorySpending = {};
  List<Map<String, dynamic>> _trend = [];
  List<Insight> _insights = [];

  final _fmt = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
  );

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final results = await Future.wait([
      db.getMonthlyIncome(month: _month),
      db.getMonthlyTotal(month: _month),
      db.getCategorySpendingForMonth(_month),
      db.getMonthlyTrend(6),
      InsightService.generate(),
    ]);
    if (!mounted) return;
    setState(() {
      _monthIncome = results[0] as double;
      _monthExpense = results[1] as double;
      _categorySpending = results[2] as Map<String, double>;
      _trend = results[3] as List<Map<String, dynamic>>;
      _insights = results[4] as List<Insight>;
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    final candidate = DateTime(_month.year, _month.month + delta);
    final now = DateTime(DateTime.now().year, DateTime.now().month);
    if (candidate.isAfter(now)) return;
    setState(() => _month = candidate);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _monthNavigator(),
                  const SizedBox(height: 16),
                  _cashFlowTiles(),
                  if (_isCurrentMonth) ...[
                    const SizedBox(height: 20),
                    _insightsCard(),
                  ],
                  const SizedBox(height: 20),
                  _categoryBreakdown(),
                  const SizedBox(height: 20),
                  _budgetStatus(),
                  const SizedBox(height: 20),
                  _trendChart(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Month navigator ─────────────────────────────────────────────────────────

  Widget _monthNavigator() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.glassRowFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorderSoft),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
            color: AppTheme.gold,
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_month),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
            color: AppTheme.gold,
            disabledColor: const Color(0xFF555577),
          ),
        ],
      ),
    );
  }

  // ── Cash-flow tiles ─────────────────────────────────────────────────────────

  Widget _cashFlowTiles() {
    final net = _monthIncome - _monthExpense;
    return Row(
      children: [
        _statTile('Income', _monthIncome, _income),
        const SizedBox(width: 10),
        _statTile('Expenses', _monthExpense, AppTheme.gold),
        const SizedBox(width: 10),
        _statTile(
          'Net',
          net,
          net >= 0 ? _income : _expenseRed,
          signed: true,
        ),
      ],
    );
  }

  Widget _statTile(String label, double value, Color color,
      {bool signed = false}) {
    final text = signed
        ? '${value >= 0 ? '+' : '-'}${_fmt.format(value.abs())}'
        : _fmt.format(value);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.glassRowFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category breakdown ──────────────────────────────────────────────────────

  Widget _categoryBreakdown() {
    final entries = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

    return _card(
      title: 'Spending by Category',
      child: entries.isEmpty
          ? _emptyHint('No expenses recorded for this month.')
          : Column(
              children: [
                for (final e in entries) ...[
                  _categoryBar(e.key, e.value, total),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _categoryBar(String category, double amount, double total) {
    final pct = total > 0 ? amount / total : 0.0;
    final color = AppConstants.categoryColors[category] ?? Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              AppConstants.categoryIcons[category] ?? Icons.more_horiz,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              _fmt.format(amount),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Budget status ───────────────────────────────────────────────────────────

  /// Reuses the Budgets screen's banner and progress-row widgets, but scoped to
  /// the month currently selected on Analytics (spending from [_categorySpending],
  /// limits from [BudgetProvider]).
  Widget _budgetStatus() {
    final budgets = context.watch<BudgetProvider>();
    final limits = budgets.limits;

    if (limits.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _budgetTitle(),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.glassRowFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassBorderSoft),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined,
                      size: 18, color: AppTheme.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Set a budget to track spending',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 18, color: Color(0xFF555577)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Over-budget categories for the SELECTED month.
    final entries = limits.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final over = [
      for (final e in entries)
        if ((_categorySpending[e.key] ?? 0) > e.value) e.key,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _budgetTitle(),
        const SizedBox(height: 12),
        if (over.isNotEmpty) BudgetOverBanner(overCategories: over),
        for (final e in entries) ...[
          BudgetProgressRow(
            category: e.key,
            limit: e.value,
            spent: _categorySpending[e.key] ?? 0,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _budgetTitle() {
    return const Text(
      'Budget status',
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── 6-month trend ───────────────────────────────────────────────────────────

  Widget _trendChart() {
    final maxVal = _trend.fold<double>(0, (m, row) {
      final e = row['expense'] as double;
      final i = row['income'] as double;
      return [m, e, i].reduce((a, b) => a > b ? a : b);
    });

    return _card(
      title: 'Income vs Expense (6 months)',
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final row in _trend)
                  Expanded(child: _trendColumn(row, maxVal)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _legend(),
        ],
      ),
    );
  }

  Widget _trendColumn(Map<String, dynamic> row, double maxVal) {
    final expense = row['expense'] as double;
    final income = row['income'] as double;
    final date = row['date'] as DateTime;
    const chartHeight = 120.0;

    double barHeight(double v) => maxVal <= 0 ? 0 : (v / maxVal) * chartHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(barHeight(income), _income),
            const SizedBox(width: 3),
            _bar(barHeight(expense), AppTheme.gold),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          DateFormat('MMM').format(date),
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 9,
      height: height < 2 ? 2 : height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }

  Widget _legend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(_income, 'Income'),
        const SizedBox(width: 20),
        _legendDot(AppTheme.gold, 'Expense'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  // ── Insights (spending anomalies) ───────────────────────────────────────────

  Widget _insightsCard() {
    return _card(
      title: 'Smart Insights',
      child: Column(
        children: [
          for (int i = 0; i < _insights.length; i++) ...[
            _insightRow(_insights[i]),
            if (i != _insights.length - 1)
              const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _insightRow(Insight insight) {
    final color = insight.severity == InsightSeverity.warning
        ? const Color(0xFFFFB74D)
        : const Color(0xFF4CAF50);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(insight.icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                insight.message,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassRowFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _emptyHint(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      ),
    );
  }
}
