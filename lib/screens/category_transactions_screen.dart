import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/providers/account_provider.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/screens/add_edit_transaction_screen.dart';
import 'package:receipto/services/database_helper.dart';
import 'package:receipto/widgets/app_page_route.dart';
import 'package:receipto/widgets/empty_state.dart';
import 'package:receipto/widgets/transaction_tile.dart';

/// Lists every transaction tagged with [value] (a category or subcategory) in
/// [month], ranked by amount. Tapping a row opens Edit Transaction; swiping
/// deletes. Opened from the Analytics "Spending by Category" drill-down.
class CategoryTransactionsScreen extends StatefulWidget {
  final String value;
  final DateTime month;

  const CategoryTransactionsScreen({
    super.key,
    required this.value,
    required this.month,
  });

  @override
  State<CategoryTransactionsScreen> createState() =>
      _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState
    extends State<CategoryTransactionsScreen> {
  List<model.Transaction> _items = [];
  bool _loading = true;

  final _fmt = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
  );

  @override
  void initState() {
    super.initState();
    // Defer the DB load + (SVG-heavy) list build until the open transition has
    // finished, so parsing icons doesn't compete with the animation and cause
    // jank. Falls back to loading immediately if there's no transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        _load();
      } else {
        void listener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            animation.removeStatusListener(listener);
            _load();
          }
        }

        animation.addStatusListener(listener);
      }
    });
  }

  Future<void> _load() async {
    final firstDay = DateTime(widget.month.year, widget.month.month, 1);
    final lastDay = DateTime(widget.month.year, widget.month.month + 1, 0);
    final items = await DatabaseHelper.instance.getTransactions(
      category: widget.value,
      from: firstDay,
      to: lastDay,
    );
    // Rank by amount, largest first.
    items.sort((a, b) => b.amount.compareTo(a.amount));
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _editTransaction(model.Transaction t) async {
    await Navigator.push(
      context,
      AppPageRoute(builder: (_) => AddEditTransactionScreen(transaction: t)),
    );
    if (!mounted) return;
    // Reflect any edits/deletions here and across the app.
    await _load();
    if (!mounted) return;
    context.read<TransactionProvider>().loadTransactions();
    context.read<AccountProvider>().loadAccounts();
  }

  Future<void> _deleteTransaction(model.Transaction t) async {
    await DatabaseHelper.instance.deleteTransaction(t.id!);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    context.read<TransactionProvider>().loadTransactions();
    context.read<AccountProvider>().loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (sum, t) => sum + t.amount);
    final monthLabel = DateFormat('MMMM yyyy').format(widget.month);

    return Scaffold(
      appBar: AppBar(title: Text(widget.value)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long,
                  title: 'No ${widget.value} transactions',
                  subtitle: 'Nothing recorded for $monthLabel.',
                )
              : Column(
                  children: [
                    // Summary header for the selected month.
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthLabel.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _fmt.format(total),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_items.length} transaction'
                            '${_items.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final t = _items[i];
                          return TransactionTile(
                            transaction: t,
                            onTap: () => _editTransaction(t),
                            onDelete: () => _deleteTransaction(t),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
