import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/account.dart';
import 'package:receipto/providers/account_provider.dart';
import 'package:receipto/widgets/glass.dart';

/// Multi-account wallet view: per-account balances, overall net worth, and
/// transfers between accounts.
class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final _fmt = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
  );

  static const Map<String, IconData> _typeIcons = {
    'cash': Icons.payments,
    'bank': Icons.account_balance,
    'ewallet': Icons.account_balance_wallet,
    'other': Icons.wallet,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Transfer',
            onPressed: () => _showTransferDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<AccountProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _netWorthCard(provider.netWorth),
              const SizedBox(height: 16),
              if (provider.accounts.isEmpty)
                _emptyHint()
              else
                for (final acc in provider.accounts) ...[
                  _accountCard(context, provider, acc),
                  const SizedBox(height: 10),
                ],
              if (provider.transfers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'RECENT TRANSFERS',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                for (final t in provider.transfers.take(5))
                  _transferRow(provider, t),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _netWorthCard(double netWorth) {
    return HeroGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NET WORTH',
              style: TextStyle(
                color: AppTheme.onGlassMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _fmt.format(netWorth),
              style: TextStyle(
                color: netWorth >= 0 ? AppTheme.textPrimary : AppTheme.danger,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total across all accounts',
              style: TextStyle(color: AppTheme.onGlassMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(
    BuildContext context,
    AccountProvider provider,
    Account acc,
  ) {
    final balance = provider.balanceOf(acc);
    return GestureDetector(
      onTap: () => _showEditAccountDialog(context, provider, acc),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.glassRowFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.glassBorderSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassBorderSoft),
              ),
              child: Icon(
                _typeIcons[acc.type] ?? Icons.wallet,
                color: AppTheme.gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acc.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    acc.type[0].toUpperCase() + acc.type.substring(1),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _fmt.format(balance),
              style: TextStyle(
                color: balance >= 0
                    ? AppTheme.textPrimary
                    : const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transferRow(AccountProvider provider, Transfer t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${t.fromAccount} → ${t.toAccount}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            _fmt.format(t.amount),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: () {
              if (t.id != null) provider.deleteTransfer(t.id!);
            },
            icon: const Icon(Icons.close, size: 16),
            color: AppTheme.textMuted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _emptyHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassRowFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorderSoft),
      ),
      child: Text(
        'Add an account to start tracking balances. Balances are computed from '
        'transactions that use the account name as their payment method, plus '
        'any transfers.',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAddAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(
        onSave: (name, type, opening) => context
            .read<AccountProvider>()
            .addAccount(name: name, type: type, openingBalance: opening),
      ),
    );
  }

  void _showEditAccountDialog(
    BuildContext context,
    AccountProvider provider,
    Account acc,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(
        existing: acc,
        onSave: (name, type, opening) => provider.updateAccount(
          acc.copyWith(name: name, type: type, openingBalance: opening),
        ),
        onDelete: () => provider.deleteAccount(acc.id!),
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    final provider = context.read<AccountProvider>();
    if (provider.accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least two accounts first.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _TransferDialog(
        accounts: provider.accountNames,
        onSave: (from, to, amount) => provider.addTransfer(
          fromAccount: from,
          toAccount: to,
          amount: amount,
          date: DateTime.now(),
        ),
      ),
    );
  }
}

// ── Account add/edit dialog ───────────────────────────────────────────────────

class _AccountDialog extends StatefulWidget {
  final Account? existing;
  final Future<void> Function(String name, String type, double opening) onSave;
  final VoidCallback? onDelete;

  const _AccountDialog({
    this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _openingController;
  late String _type;
  String? _error;

  static const _types = ['cash', 'bank', 'ewallet', 'other'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _openingController = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.openingBalance.toStringAsFixed(2)
          : '',
    );
    _type = widget.existing?.type ?? 'cash';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter an account name');
      return;
    }
    final opening = double.tryParse(_openingController.text.trim()) ?? 0;
    final navigator = Navigator.of(context);
    widget.onSave(name, _type, opening);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Account' : 'New Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Account name',
              hintText: 'e.g. GX Bank, Cash',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: _types
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t[0].toUpperCase() + t.substring(1)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? 'cash'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _openingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Opening balance (RM)',
              prefixText: 'RM ',
            ),
          ),
        ],
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              widget.onDelete!();
              navigator.pop();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ── Transfer dialog ───────────────────────────────────────────────────────────

class _TransferDialog extends StatefulWidget {
  final List<String> accounts;
  final void Function(String from, String to, double amount) onSave;

  const _TransferDialog({required this.accounts, required this.onSave});

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late String _from;
  late String _to;
  final _amountController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _from = widget.accounts.first;
    _to = widget.accounts.length > 1 ? widget.accounts[1] : widget.accounts.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (_from == _to) {
      setState(() => _error = 'Choose two different accounts');
      return;
    }
    final navigator = Navigator.of(context);
    widget.onSave(_from, _to, amount);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _from,
            decoration: const InputDecoration(labelText: 'From'),
            items: widget.accounts
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _from = v ?? _from),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _to,
            decoration: const InputDecoration(labelText: 'To'),
            items: widget.accounts
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _to = v ?? _to),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (RM)',
              prefixText: 'RM ',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Transfer')),
      ],
    );
  }
}
