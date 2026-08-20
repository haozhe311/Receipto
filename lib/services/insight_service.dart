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

  /// Builds the list of insights for [month] (defaults to the current
  /// calendar month), most important first. Category-spike detection still
  /// compares against the months immediately before [month], whichever month
  /// that is. Budget overruns are likewise scoped to [month].
  static Future<List<Insight>> generate({DateTime? month}) async {
    final db = DatabaseHelper.instance;
    final target = month ?? DateTime.now();
    final monthStart = DateTime(target.year, target.month, 1);
    final monthEnd = DateTime(target.year, target.month + 1, 0);

    final results = await Future.wait([
      db.getMonthlySummary(), // per month/category expense totals
      db.getTransactions(from: monthStart, to: monthEnd),
      db.getCategorySpendingForMonth(target),
      db.getSetting('categories'),
      db.getBudgets(),
    ]);
    final monthlySummary = results[0] as List<Map<String, dynamic>>;
    final monthTxns = (results[1] as List<model.Transaction>)
        .where((t) => !t.isIncome)
        .toList();
    final rawCategorySpend = results[2] as Map<String, double>;
    final categoriesJson = results[3] as String?;
    final budgetLimits = results[4] as Map<String, double>;

    final rolledUpSpend =
        DatabaseHelper.rollUpCategorySpending(rawCategorySpend, categoriesJson);

    final insights = <Insight>[];
    final targetMonthKey =
        '${target.year.toString().padLeft(4, '0')}-${target.month.toString().padLeft(2, '0')}';

    // Ordered roughly by how actionable each insight type is.
    insights.addAll(_budgetOverruns(budgetLimits, rolledUpSpend));
    insights.addAll(_categorySpikes(monthlySummary, targetMonthKey));
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

  /// Flags categories whose rolled-up spend for the browsed month exceeds
  /// their budget. Sorted worst-over-budget first; capped to avoid flooding
  /// the card if many categories are over at once.
  static List<Insight> _budgetOverruns(
    Map<String, double> limits,
    Map<String, double> spend,
  ) {
    final overs = <(String category, double spent, double limit)>[];
    limits.forEach((category, limit) {
      if (limit <= 0) return;
      final spent = spend[category] ?? 0;
      if (spent > limit) overs.add((category, spent, limit));
    });
    // Worst overrun (by percentage over) first.
    overs.sort((a, b) => (b.$2 / b.$3).compareTo(a.$2 / a.$3));

    return [
      for (final (category, spent, limit) in overs.take(3))
        Insight(
          icon: Icons.warning_amber,
          title: '$category budget exceeded',
          message:
              "You've spent RM ${spent.toStringAsFixed(2)} of your "
              'RM ${limit.toStringAsFixed(2)} $category budget — '
              '${(((spent / limit) - 1) * 100).toStringAsFixed(0)}% over.',
          severity: InsightSeverity.warning,
        ),
    ];
  }

  /// Flags categories whose spend in [targetMonthKey] is well above their
  /// recent average (mean of up to the 3 months immediately before it).
  static List<Insight> _categorySpikes(
    List<Map<String, dynamic>> summary,
    String targetMonthKey,
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
      final current = months[targetMonthKey];
      if (current == null || current <= 0) return;

      final past = (months.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key)))
          .where((e) => e.key.compareTo(targetMonthKey) < 0)
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
              'You spent RM ${current.toStringAsFixed(2)} on $cat that month — '
              '${pct.toStringAsFixed(0)}% above the recent average of '
              'RM ${avg.toStringAsFixed(2)}.',
          severity: InsightSeverity.warning,
        ));
      }
    });
    return out;
  }

  /// Flags any single expense that is more than 2× its OWN category's
  /// average transaction size this month.
  ///
  /// Comparing against a single all-categories average (the original design)
  /// meant fixed bills like Rent or Tuition — which are structurally larger
  /// than day-to-day categories like Food — got flagged as "unusual" every
  /// single month even though nothing was actually anomalous. Comparing each
  /// transaction against its own category's typical size fixes that: a
  /// RM250 Rent payment is normal next to other RM250 Rent payments, while a
  /// RM120 Dinner really does stand out next to typical RM8–15 Dinners.
  static List<Insight> _largeTransactions(List<model.Transaction> txns) {
    if (txns.length < 4) return [];

    final byCategory = <String, List<model.Transaction>>{};
    for (final t in txns) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }

    final flagged = <(model.Transaction txn, double avg)>[];
    for (final t in txns) {
      final peers = byCategory[t.category]!;
      // Need at least one other transaction in the category to have a
      // meaningful "typical size" to compare against.
      if (peers.length < 2) continue;
      final avg = peers.fold<double>(0, (s, p) => s + p.amount) / peers.length;
      if (avg > 0 && t.amount > avg * 2) {
        flagged.add((t, avg));
      }
    }
    // Most anomalous relative to their own category norm, first. Cap to two
    // to avoid flooding the list.
    flagged.sort(
      (a, b) => (b.$1.amount / b.$2).compareTo(a.$1.amount / a.$2),
    );

    return [
      for (final (txn, avg) in flagged.take(2))
        Insight(
          icon: Icons.priority_high,
          title: 'Large transaction',
          message:
              '${txn.merchant} (${txn.category}): RM ${txn.amount.toStringAsFixed(2)} '
              'is well above your typical ${txn.category} spend '
              '(avg RM ${avg.toStringAsFixed(2)}).',
          severity: InsightSeverity.warning,
        ),
    ];
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
