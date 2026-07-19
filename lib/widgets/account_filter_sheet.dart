import 'package:flutter/material.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/account.dart';
import 'package:receipto/widgets/category_picker_sheet.dart';

/// Result of the Home account filter sheet.
sealed class AccountPick {
  const AccountPick();
}

/// A chosen account (payment method) value.
class AccountPickValue extends AccountPick {
  final String value;
  const AccountPickValue(this.value);
}

/// The "All Accounts" row was chosen — clear the account filter.
class AccountPickAll extends AccountPick {
  const AccountPickAll();
}

/// "Filter by Account" sheet for the Home screen. Reuses the shared [PickerSheet]
/// chrome and row styling used by Select Account / Select Category, with an
/// "All Accounts" row pinned at the top (styled like "All Categories") that
/// clears the filter. Accounts have no sub-level, so there is no drill-down, and
/// the list is short enough not to need a search field.
class AccountFilterSheet extends StatefulWidget {
  final List<Account> accounts;
  final String? selected;

  const AccountFilterSheet({
    super.key,
    required this.accounts,
    required this.selected,
  });

  @override
  State<AccountFilterSheet> createState() => _AccountFilterSheetState();
}

class _AccountFilterSheetState extends State<AccountFilterSheet> {
  // Owned only to satisfy PickerSheet's API; the search field is hidden.
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specs = <RowSpec>[
      RowSpec(
        label: 'All Accounts',
        leading: const Icon(Icons.apps, size: kCatIconSize, color: AppTheme.gold),
        isSelected: widget.selected == null,
        onSelect: () => Navigator.of(context).pop(const AccountPickAll()),
      ),
      for (final a in widget.accounts)
        RowSpec(
          label: a.name,
          leading: Icon(
            AppConstants.accountTypeIcons[a.type] ?? Icons.wallet,
            size: kCatIconSize,
            color: AppTheme.gold,
          ),
          isSelected: a.name == widget.selected,
          onSelect: () => Navigator.of(context).pop(AccountPickValue(a.name)),
        ),
    ];

    return PickerSheet(
      title: 'Filter by Account',
      fillHeight: true,
      showSearch: false,
      searchController: _searchController,
      onQueryChanged: (_) {},
      rows: pickerRows(specs),
    );
  }
}
