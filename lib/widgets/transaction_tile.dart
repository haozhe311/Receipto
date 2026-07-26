import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/category_glyphs.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/widgets/glass.dart';

/// A single transaction row displayed in the home screen list.
///
/// Shows the category icon, merchant name, date, and amount.
/// Supports tap (edit) and swipe-to-dismiss (delete with confirmation).
class TransactionTile extends StatelessWidget {
  final model.Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: AppConstants.currencyLocale,
      symbol: AppConstants.currencySymbol,
    );
    final dateFormat = DateFormat('dd MMM yyyy');
    final visual =
        context.read<CategoryProvider>().visualForValue(transaction.category);
    final color = visual.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: ValueKey(transaction.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: AppTheme.danger),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => onDelete(),
        child: ListGlassRow(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Category icon badge (white glyph on the category colour).
              CategoryIconBadge(
                assetPath: visual.assetPath,
                background: color,
                size: 44,
              ),
              const SizedBox(width: 12),
              // Subcategory (primary) + merchant + date + account.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subcategory — the prominent line (larger than the rest).
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (transaction.isOcr)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.document_scanner,
                              size: 13,
                              color: AppTheme.gold.withAlpha(180),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.paymentMethod,
                      style: const TextStyle(
                        color: AppTheme.onGlassFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount (signed + coloured) with the date beneath it.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.isIncome ? '+' : '-'}'
                    '${currencyFormat.format(transaction.amount)}',
                    style: TextStyle(
                      color: transaction.isIncome
                          ? AppTheme.positive
                          : AppTheme.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(transaction.date),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
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

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Delete "${transaction.merchant}" for '
          '${NumberFormat.currency(locale: AppConstants.currencyLocale, symbol: AppConstants.currencySymbol).format(transaction.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
