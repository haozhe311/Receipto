import 'package:flutter/material.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/services/database_helper.dart';

/// Severity/tone of an insight, used to pick its accent colour.
enum InsightSeverity { info, warning }

/// A single spending insight surfaced to the user.
class Insight {
  final IconData icon;
  final String title;
  final String message;
  final InsightSeverity severity;

  const Insight({
    required this.icon,
    required this.title,
    required this.message,
    this.severity = InsightSeverity.info,
  });
}

/// Rule-based spending-anomaly detection. No ML — just transparent heuristics
/// over the local transaction history, which keeps it explainable for a report.
class InsightService {
  InsightService._();

  /// Builds the list of insights for the current month, most important first.
  static Future<List<Insight>> generate() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final results = await Future.wait([
      db.getMonthlySummary(), // per month/category expense totals
      db.getTransactions(from: monthStart, to: monthEnd),
    ]);
    final monthlySummary = results[0] as List<Map<String, dynamic>>;
    final monthTxns = (results[1] as List<model.Transaction>)
        .where((t) => !t.isIncome)
        .toList();

    final insights = <Insight>[];
    final currentMonthKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

    insights.addAll(_categorySpikes(monthlySummary, currentMonthKey));
    insights.addAll(_largeTransactions(monthTxns));
    insights.addAll(_duplicateCharges(monthTxns));
    insights.addAll(_frequentMerchants(monthTxns));

    if (insights.isEmpty) {
      insights.add(const Insight(
        icon: Icons.check_circle_outline,
        title: 'Nothing unusual',
        message: 'Your spending this month looks normal. Keep it up!',
      ));
    }
    return insights;
  }

  /// Flags categories whose current-month spend is well above their recent
  /// average (mean of up to the previous 3 months that had spending).
  static List<Insight> _categorySpikes(
    List<Map<String, dynamic>> summary,
    String currentMonthKey,
  ) {
    // Build {category: {month: total}}.
    final byCat = <String, Map<String, double>>{};
    for (final row in summary) {
      final month = row['month'] as String;
      final cat = row['category'] as String;
      final total = (row['total'] as num).toDouble();
      byCat.putIfAbsent(cat, () => {})[month] = total;
    }

    final out = <Insight>[];
    byCat.forEach((cat, months) {
      final current = months[currentMonthKey];
      if (current == null || current <= 0) return;

      final past = (months.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key)))
          .where((e) => e.key != currentMonthKey)
          .take(3)
          .map((e) => e.value)
          .toList();
      if (past.isEmpty) return;

      final avg = past.reduce((a, b) => a + b) / past.length;
      if (avg <= 0) return;

      if (current > avg * 1.5) {
        final pct = ((current / avg) - 1) * 100;
        out.add(Insight(
          icon: Icons.trending_up,
          title: '$cat spending is up',
          message:
              'You spent RM ${current.toStringAsFixed(2)} on $cat this month — '
              '${pct.toStringAsFixed(0)}% above your recent average of '
              'RM ${avg.toStringAsFixed(2)}.',
          severity: InsightSeverity.warning,
        ));
      }
    });
    return out;
  }

  /// Flags any single expense that is more than 2× the average expense size
  /// this month.
  static List<Insight> _largeTransactions(List<model.Transaction> txns) {
    if (txns.length < 4) return [];
    final avg =
        txns.fold<double>(0, (s, t) => s + t.amount) / txns.length;
    if (avg <= 0) return [];

    final out = <Insight>[];
    for (final t in txns) {
      if (t.amount > avg * 2) {
        out.add(Insight(
          icon: Icons.priority_high,
          title: 'Large transaction',
          message:
              '${t.merchant}: RM ${t.amount.toStringAsFixed(2)} is well above '
              'your typical spend this month.',
          severity: InsightSeverity.warning,
        ));
      }
    }
    // Cap to the two biggest to avoid flooding the list.
    out.sort((a, b) => a.title.compareTo(b.title));
    return out.take(2).toList();
  }

  /// Detects likely duplicate charges: same merchant and amount within 3 days.
  static List<Insight> _duplicateCharges(List<model.Transaction> txns) {
    final out = <Insight>[];
    for (int i = 0; i < txns.length; i++) {
      for (int j = i + 1; j < txns.length; j++) {
        final a = txns[i];
        final b = txns[j];
        if (a.merchant.toLowerCase() == b.merchant.toLowerCase() &&
            (a.amount - b.amount).abs() < 0.01 &&
            a.date.difference(b.date).inDays.abs() <= 3) {
          out.add(Insight(
            icon: Icons.copy_all,
            title: 'Possible duplicate',
            message:
                'Two charges of RM ${a.amount.toStringAsFixed(2)} at '
                '${a.merchant} within a few days. Check for a double charge.',
            severity: InsightSeverity.warning,
          ));
          return out; // one duplicate warning is enough
        }
      }
    }
    return out;
  }

  /// Highlights a merchant visited unusually often this month.
  static List<Insight> _frequentMerchants(List<model.Transaction> txns) {
    final counts = <String, int>{};
    final totals = <String, double>{};
    for (final t in txns) {
      final key = t.merchant;
      counts[key] = (counts[key] ?? 0) + 1;
      totals[key] = (totals[key] ?? 0) + t.amount;
    }

    String? top;
    int topCount = 0;
    counts.forEach((merchant, count) {
      if (count > topCount) {
        topCount = count;
        top = merchant;
      }
    });

    if (top != null && topCount >= 5) {
      return [
        Insight(
          icon: Icons.repeat,
          title: 'Frequent spending',
          message:
              '$topCount visits to $top this month totalling '
              'RM ${totals[top]!.toStringAsFixed(2)}.',
        ),
      ];
    }
    return [];
  }
}
