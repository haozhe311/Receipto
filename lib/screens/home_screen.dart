import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/screens/add_edit_transaction_screen.dart';
import 'package:receipto/widgets/category_chip.dart';
import 'package:receipto/widgets/empty_state.dart';
import 'package:receipto/widgets/summary_card.dart';
import 'package:receipto/widgets/transaction_tile.dart';

/// The main dashboard screen showing spending summary and transaction list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Scan Receipt',
            onPressed: () {
              // TODO: Navigate to OCR scan screen (Step 5)
            },
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Spending summary card
              SummaryCard(
                monthlyTotal: provider.monthlyTotal,
                transactionCount: provider.transactionCount,
              ),

              // Category filter chips
              _CategoryFilterBar(
                selectedCategory: provider.selectedCategory,
                onCategorySelected: provider.filterByCategory,
              ),

              // Transaction list or empty state
              Expanded(
                child: provider.transactions.isEmpty
                    ? const EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: provider.transactions.length,
                        itemBuilder: (context, index) {
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
          MaterialPageRoute(
            builder: (_) => const AddEditTransactionScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Horizontal scrollable row of category filter chips.
class _CategoryFilterBar extends StatelessWidget {
  final String? selectedCategory;
  final void Function(String?) onCategorySelected;

  const _CategoryFilterBar({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" chip
          CategoryChip(
            category: 'All',
            isSelected: selectedCategory == null,
            onTap: () => onCategorySelected(null),
          ),
          // Category chips
          ...AppConstants.categories.map(
            (cat) => CategoryChip(
              category: cat,
              isSelected: selectedCategory == cat,
              onTap: () => onCategorySelected(cat),
            ),
          ),
        ],
      ),
    );
  }
}
