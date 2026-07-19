import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/account_provider.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/screens/add_edit_transaction_screen.dart';
import 'package:receipto/screens/wallets_screen.dart';
import 'package:receipto/widgets/account_filter_sheet.dart';
import 'package:receipto/widgets/category_picker_sheet.dart';
import 'package:receipto/widgets/empty_state.dart';
import 'package:receipto/widgets/glass.dart';
import 'package:receipto/widgets/summary_card.dart';
import 'package:receipto/widgets/transaction_tile.dart';

/// The main dashboard screen showing spending summary and transaction list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastSeenMonth;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<TransactionProvider>();
    // Don't trigger loadMore while the main load is still running.
    if (provider.isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      provider.loadMoreTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          // Scroll to top whenever the user navigates to a different month.
          if (_lastSeenMonth != provider.selectedMonth) {
            _lastSeenMonth = provider.selectedMonth;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
            });
          }

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Net worth (sum of all account balances) → Wallets.
              // Global, always-current figure: kept above and visually
              // separated from the month/category-scoped section below.
              const SizedBox(height: 12),
              const _NetWorthCard(),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: AppTheme.border, height: 1),
              ),

              // ── Month-scoped section ──────────────────────────────────
              // Spending summary card with month navigator
              SummaryCard(
                monthlyTotal: provider.displayTotal,
                transactionCount: provider.transactionCount,
                selectedMonth: provider.selectedMonth,
                isCurrentMonth: provider.isCurrentMonth,
                onPreviousMonth: () => provider.navigateMonth(-1),
                onNextMonth: () => provider.navigateMonth(1),
                selectedCategory: provider.selectedCategory,
                selectedAccount: provider.selectedAccount,
              ),

              // Cash-flow strip (only in the unfiltered month view)
              if (!provider.hasFilter)
                _CashFlowStrip(
                  income: provider.monthlyIncome,
                  expense: provider.monthlyTotal,
                  net: provider.netSavings,
                ),

              // Category + account filter controls (independent, AND-combined)
              _HomeFilters(
                selectedCategory: provider.selectedCategory,
                selectedAccount: provider.selectedAccount,
              ),

              // Transaction list or empty state
              Expanded(
                child: provider.transactions.isEmpty
                    ? const EmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 80),
                        // +1 for the bottom loading indicator slot
                        itemCount: provider.transactions.length + 1,
                        itemBuilder: (context, index) {
                          // Last slot: loading indicator or end spacer
                          if (index == provider.transactions.length) {
                            if (provider.isLoadingMore) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }

                          final transaction = provider.transactions[index];
                          return TransactionTile(
                            transaction: transaction,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditTransactionScreen(
                                  transaction: transaction,
                                ),
                              ),
                            ),
                            onDelete: () {
                              if (transaction.id != null) {
                                provider.deleteTransaction(transaction.id!);
                                // Refresh account balances / net worth.
                                context.read<AccountProvider>().loadAccounts();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditTransactionScreen()),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// A compact card showing net worth (sum of all account balances), tapping
/// through to Wallets & Balances. Reads [AccountProvider] — the same source
/// the Wallets screen uses — so the calculation is not duplicated.
class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: AppConstants.currencyLocale,
      symbol: AppConstants.currencySymbol,
    );
    return Consumer<AccountProvider>(
      builder: (context, accounts, _) {
        final netWorth = accounts.netWorth;
        return HeroGlassCard(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WalletsScreen()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 16,
                    color: AppTheme.gold,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'NET WORTH',
                    style: TextStyle(
                      color: AppTheme.onGlassMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                fmt.format(netWorth),
                style: TextStyle(
                  color: netWorth >= 0
                      ? Colors.white
                      : const Color(0xFFFF8A8A),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A compact three-cell strip showing the month's income, expenses, and net.
class _CashFlowStrip extends StatelessWidget {
  final double income;
  final double expense;
  final double net;

  const _CashFlowStrip({
    required this.income,
    required this.expense,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: AppConstants.currencyLocale,
      symbol: AppConstants.currencySymbol,
    );
    const incomeGreen = Color(0xFF7CE0A8);
    final netColor = net >= 0 ? incomeGreen : const Color(0xFFFF8A8A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          _cell(context, 'Income', fmt.format(income), incomeGreen),
          const SizedBox(width: 8),
          _cell(context, 'Expenses', fmt.format(expense), AppTheme.gold),
          const SizedBox(width: 8),
          _cell(
            context,
            'Net',
            '${net >= 0 ? '+' : '-'}${fmt.format(net.abs())}',
            netColor,
          ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Expanded(
      child: ListGlassRow(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        borderRadius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.onGlassMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width "Filter" row for the Home transaction list, styled like the
/// Category / Account selector rows in Add Transaction: filter icon + "Filter"
/// on the left, and a chevron on the right — or, once a filter is active, the
/// selected category's icon + name. Tapping opens the shared [CategorySheet],
/// configured for category-level filtering: no search, no subcategory
/// drill-down, and an "All Categories" row to clear.
class _HomeFilters extends StatelessWidget {
  final String? selectedCategory;
  final String? selectedAccount;

  const _HomeFilters({
    required this.selectedCategory,
    required this.selectedAccount,
  });

  Future<void> _openCategorySheet(BuildContext context) async {
    final catProvider = context.read<CategoryProvider>();
    final txProvider = context.read<TransactionProvider>();
    final result = await showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategorySheet(
        categories: catProvider.categories,
        selected: selectedCategory,
        title: 'Filter by Category',
        allRowLabel: 'All Categories',
        showManage: false,
        showSearch: false,
        allowSubcategoryDrillDown: false,
      ),
    );
    if (result is CategoryPickValue) {
      // Category-level filter: match the parent plus all of its subcategories,
      // so e.g. "Transport" shows Fuel + Maintenance + directly-tagged rows.
      final cat = catProvider.byName(result.value);
      txProvider.filterByCategory(
        result.value,
        includeValues: [result.value, if (cat != null) ...cat.subcategories],
      );
    } else if (result is CategoryPickAll) {
      txProvider.filterByCategory(null);
    }
  }

  Future<void> _openAccountSheet(BuildContext context) async {
    final accProvider = context.read<AccountProvider>();
    final txProvider = context.read<TransactionProvider>();
    final result = await showModalBottomSheet<AccountPick>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AccountFilterSheet(
        accounts: accProvider.accounts,
        selected: selectedAccount,
      ),
    );
    if (result is AccountPickValue) {
      txProvider.filterByAccount(result.value);
    } else if (result is AccountPickAll) {
      txProvider.filterByAccount(null);
    }
  }

  /// Active leading icon for the category button (its swatch icon), or null.
  Widget? _categoryLeading(BuildContext context) {
    if (selectedCategory == null) return null;
    final option = CategoryIcons.resolve(
      selectedCategory!,
      context.read<CategoryProvider>().byName(selectedCategory!)?.iconKey,
    );
    return Icon(option.icon, size: 18, color: option.color);
  }

  /// Active leading icon for the account button (its type icon), or null.
  Widget? _accountLeading(BuildContext context) {
    if (selectedAccount == null) return null;
    final matches = context
        .read<AccountProvider>()
        .accounts
        .where((a) => a.name == selectedAccount);
    final type = matches.isEmpty ? 'other' : matches.first.type;
    return Icon(
      AppConstants.accountTypeIcons[type] ?? Icons.wallet,
      size: 18,
      color: AppTheme.gold,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _FilterButton(
              idleIcon: Icons.filter_list,
              activeLeading: _categoryLeading(context),
              activeLabel: selectedCategory,
              onTap: () => _openCategorySheet(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterButton(
              idleIcon: Icons.account_balance_wallet_outlined,
              activeLeading: _accountLeading(context),
              activeLabel: selectedAccount,
              onTap: () => _openAccountSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// One half-width filter button. Shows a filter icon + "Filter" when inactive,
/// or the selected item's icon + name (ellipsised) when a filter is applied.
class _FilterButton extends StatelessWidget {
  final IconData idleIcon;
  final Widget? activeLeading;
  final String? activeLabel;
  final VoidCallback onTap;

  const _FilterButton({
    required this.idleIcon,
    required this.onTap,
    this.activeLeading,
    this.activeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeLabel != null;
    return ListGlassRow(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          active
              ? activeLeading!
              : Icon(idleIcon, size: 18, color: AppTheme.onGlass),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activeLabel ?? 'Filter',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? AppTheme.gold : AppTheme.onGlass,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppTheme.onGlassFaint,
          ),
        ],
      ),
    );
  }
}
