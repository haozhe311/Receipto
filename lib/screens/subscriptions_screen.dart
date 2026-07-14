import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/recurring_transaction.dart';
import 'package:receipto/providers/recurring_provider.dart';
import 'package:receipto/screens/add_edit_recurring_screen.dart';

/// Focused view of recurring items flagged as subscriptions, with the total
/// monthly cost and upcoming renewal dates.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
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
      appBar: AppBar(title: const Text('Subscriptions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AddEditRecurringScreen(defaultSubscription: true),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: Consumer<RecurringProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final subs = provider.subscriptions;
          if (subs.isEmpty) {
            return _empty();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _totalCard(provider.monthlySubscriptionCost),
              const SizedBox(height: 16),
              for (final sub in subs) ...[
                _subCard(context, sub),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _totalCard(double monthly) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY SUBSCRIPTION COST',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _fmt.format(monthly),
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '≈ ${_fmt.format(monthly * 12)} per year',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _subCard(BuildContext context, RecurringTransaction sub) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddEditRecurringScreen(existing: sub),
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
              child: Icon(Icons.subscriptions,
                  color: AppTheme.gold.withAlpha(220), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Renews ${DateFormat('dd MMM yyyy').format(sub.nextDate)}'
                    '${sub.active ? '' : ' · paused'}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _fmt.format(sub.amount),
              style: const TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
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
            const Icon(Icons.subscriptions_outlined,
                size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'No subscriptions tracked',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add Netflix, Spotify, gym, or any recurring bill to see your '
              'monthly subscription spend.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
