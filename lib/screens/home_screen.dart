import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/screens/add_edit_transaction_screen.dart';
import 'package:receipto/screens/ocr_scan_screen.dart';
import 'package:receipto/widgets/category_chip.dart';
import 'package:receipto/widgets/empty_state.dart';
import 'package:receipto/widgets/summary_card.dart';
import 'package:receipto/widgets/transaction_tile.dart';

/// Shows a bottom sheet so the user can choose between camera and gallery
/// before navigating to [OcrScanScreen].
void _showScanSourceSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Scan Receipt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.camera_alt)),
            title: const Text('Take Photo'),
            subtitle: const Text('Open the device camera'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const OcrScanScreen(initialSource: ImageSource.camera),
                ),
              );
            },
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.photo_library)),
            title: const Text('Choose from Gallery'),
            subtitle: const Text('Pick an existing photo'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const OcrScanScreen(initialSource: ImageSource.gallery),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

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
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Scan Receipt',
            onPressed: () => _showScanSourceSheet(context),
          ),
        ],
      ),
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
              // Spending summary card with month navigator
              SummaryCard(
                monthlyTotal: provider.displayTotal,
                transactionCount: provider.transactionCount,
                selectedMonth: provider.selectedMonth,
                isCurrentMonth: provider.isCurrentMonth,
                onPreviousMonth: () => provider.navigateMonth(-1),
                onNextMonth: () => provider.navigateMonth(1),
                selectedCategory: provider.selectedCategory,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
    final categories = context.watch<CategoryProvider>().categories;
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
          // Dynamic category chips from CategoryProvider
          ...categories.map(
            (cat) => CategoryChip(
              category: cat.name,
              emoji: cat.emoji,
              isSelected: selectedCategory == cat.name,
              onTap: () => onCategorySelected(cat.name),
            ),
          ),
        ],
      ),
    );
  }
}
