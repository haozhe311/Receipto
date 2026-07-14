import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/recurring_transaction.dart';
import 'package:receipto/providers/recurring_provider.dart';
import 'package:receipto/screens/add_edit_recurring_screen.dart';

/// Lists all recurring transaction templates and lets the user manage them.
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final _fmt = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecurringProvider>().loadRecurring();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddEditRecurringScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: Consumer<RecurringProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.items.isEmpty) {
            return _empty();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Recurring transactions post automatically on their next date '
                'when you open the app.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final item in provider.items) ...[
                _recurringCard(context, provider, item),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.autorenew, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'No recurring transactions',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add rent, salary, or bills that repeat weekly or monthly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recurringCard(
    BuildContext context,
    RecurringProvider provider,
    RecurringTransaction item,
  ) {
    final color = item.isIncome
        ? const Color(0xFF4CAF50)
        : (AppConstants.categoryColors[item.category] ?? Colors.grey);
    final icon = item.isIncome
        ? Icons.savings
        : (AppConstants.categoryIcons[item.category] ?? Icons.more_horiz);

    return Opacity(
      opacity: item.active ? 1 : 0.5,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditRecurringScreen(existing: item),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.merchant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (item.isSubscription)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.subscriptions,
                                size: 13, color: AppTheme.gold.withAlpha(200)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.frequency == 'weekly' ? 'Weekly' : 'Monthly'} · '
                      'next ${DateFormat('dd MMM').format(item.nextDate)}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.isIncome ? '+' : ''}${_fmt.format(item.amount)}',
                    style: TextStyle(
                      color: item.isIncome
                          ? const Color(0xFF4CAF50)
                          : AppTheme.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: item.active,
                      activeColor: AppTheme.gold,
                      onChanged: (_) => provider.toggleActive(item),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
