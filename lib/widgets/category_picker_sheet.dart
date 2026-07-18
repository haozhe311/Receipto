import 'package:flutter/material.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/widgets/glass.dart';

/// Shared full-height category picker used by both the Add Transaction
/// "Select Category" flow and the Home "Filter by Category" flow.
///
/// Everything visual lives here — row metrics, dividers, the sheet chrome, and
/// the two-step (category → subcategory) navigation — so the two call sites stay
/// pixel-identical and a future style tweak only has to change one place.

// ── Result type ───────────────────────────────────────────────────────────────

/// Result of the category picker.
sealed class CategoryPick {
  const CategoryPick();
}

/// A chosen category or subcategory value.
class CategoryPickValue extends CategoryPick {
  final String value;
  const CategoryPickValue(this.value);
}

/// The "All Categories" row was chosen — i.e. clear the filter / no filter.
/// Only offered when the sheet is built with an `allRowLabel`.
class CategoryPickAll extends CategoryPick {
  const CategoryPickAll();
}

/// A request to open Manage Categories (from the header pencil).
class CategoryPickManage extends CategoryPick {
  const CategoryPickManage();
}

// ── Icon helper ───────────────────────────────────────────────────────────────

/// Resolves a category's leading widget: its icon swatch, or the legacy emoji
/// for categories saved before swatches existed. Shared by the selector row and
/// the picker sheet so they always agree.
Widget categoryIconWidget(
  String name,
  String? iconKey,
  String emoji, [
  double size = 20,
]) {
  final hasSwatch =
      iconKey != null || CategoryIcons.builtInKeyFor(name) != null;
  if (!hasSwatch && emoji.isNotEmpty) {
    return Text(emoji, style: TextStyle(fontSize: size * 0.85, height: 1));
  }
  final option = CategoryIcons.resolve(name, iconKey);
  return Icon(option.icon, size: size, color: option.color);
}

// ── Row styling ───────────────────────────────────────────────────────────────
// Tuned to a Money Manager–style picker: large bold labels, roomy rows, and
// larger icons. Every picker row goes through [pickerRows] with these metrics.
const double kCatLabelSize = 20;
const FontWeight kCatLabelWeight = FontWeight.w700;
const double kCatRowHeight = 64;
const double kCatLeadingWidth = 34;
const double kCatIconSize = 26;
const double kSubIconSize = 22;

/// The one divider drawn between every picker-sheet row.
const Divider kPickerDivider = Divider(
  height: 1,
  thickness: 1,
  indent: 16,
  endIndent: 16,
  color: AppTheme.border,
);

/// Spec for a single picker-sheet row. Keeping every sheet on this one type
/// means their rows go through [pickerRows] and stay visually identical.
class RowSpec {
  final String label;
  final Widget leading;
  final bool isSelected;
  final VoidCallback onSelect;
  final bool showCheck;
  final Widget? trailing;

  const RowSpec({
    required this.label,
    required this.leading,
    required this.isSelected,
    required this.onSelect,
    this.showCheck = true,
    this.trailing,
  });
}

/// Builds the divider-separated [OptionRow]s shared by the picker sheets,
/// applying the common label/row/icon metrics in one place.
List<Widget> pickerRows(List<RowSpec> specs) {
  final rows = <Widget>[];
  for (final s in specs) {
    if (rows.isNotEmpty) rows.add(kPickerDivider);
    rows.add(
      OptionRow(
        label: s.label,
        leading: s.leading,
        isSelected: s.isSelected,
        showCheck: s.showCheck,
        trailing: s.trailing,
        labelSize: kCatLabelSize,
        labelWeight: kCatLabelWeight,
        rowHeight: kCatRowHeight,
        leadingWidth: kCatLeadingWidth,
        onSelect: s.onSelect,
      ),
    );
  }
  return rows;
}

/// One selectable option row. Uniform height and easy to scan.
///
/// [showCheck] draws a check when [isSelected] (default). [trailing] adds extra
/// trailing content (e.g. a selected-subcategory badge + a navigate chevron on
/// a parent category row).
class OptionRow extends StatelessWidget {
  final String label;
  final Widget leading;
  final bool isSelected;
  final VoidCallback onSelect;
  final bool showCheck;
  final Widget? trailing;

  /// Row metrics. Defaults match the compact account rows; the category /
  /// subcategory sheets pass larger values for a roomier, bolder look.
  final double labelSize;
  final FontWeight labelWeight;
  final double rowHeight;
  final double leadingWidth;

  const OptionRow({
    super.key,
    required this.label,
    required this.leading,
    required this.isSelected,
    required this.onSelect,
    this.showCheck = true,
    this.trailing,
    this.labelSize = 14,
    this.labelWeight = FontWeight.normal,
    this.rowHeight = 52,
    this.leadingWidth = 24,
  });

  @override
  Widget build(BuildContext context) {
    // Never let the selected state render *lighter* than the base weight.
    final weight = (isSelected && labelWeight.index < FontWeight.w600.index)
        ? FontWeight.w600
        : labelWeight;
    return InkWell(
      onTap: onSelect,
      child: Container(
        height: rowHeight,
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: [
            SizedBox(
              width: leadingWidth,
              child: Center(child: leading),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppTheme.gold : AppTheme.textPrimary,
                  fontSize: labelSize,
                  fontWeight: weight,
                ),
              ),
            ),
            if (isSelected && showCheck)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check, size: 18, color: AppTheme.gold),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ── Sheet chrome ──────────────────────────────────────────────────────────────

/// Shared chrome for the selector bottom sheets: drag handle, title, an optional
/// trailing [action], a search field, and a scrollable list of rows.
class PickerSheet extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final List<Widget> rows;
  final Widget? action;

  /// When true the sheet expands to near-full height (from just below the app
  /// bar to the bottom); otherwise it fits its content up to 75% of the screen.
  final bool fillHeight;

  /// When false the search field is hidden (for short lists that don't need it).
  final bool showSearch;

  const PickerSheet({
    super.key,
    required this.title,
    required this.searchController,
    required this.onQueryChanged,
    required this.rows,
    this.action,
    this.fillHeight = false,
    this.showSearch = true,
  });

  Widget _listArea() {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Text(
            'No matches',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }
    return ListView(shrinkWrap: !fillHeight, children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;

    final column = Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, action != null ? 4 : 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
        fillHeight
            ? Expanded(child: _listArea())
            : Flexible(child: _listArea()),
        const SizedBox(height: 8),
      ],
    );

    if (fillHeight) {
      // From just below the app bar to the bottom, shrinking above the keyboard.
      final height =
          media.size.height - media.viewPadding.top - kToolbarHeight - keyboard;
      return GlassSheetBackground(
        child: SizedBox(
          height: height > 0 ? height : null,
          child: SafeArea(top: false, child: column),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: GlassSheetBackground(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
          child: SafeArea(top: false, child: column),
        ),
      ),
    );
  }
}

// ── Step 1: category picker ───────────────────────────────────────────────────

/// Step 1 — category picker.
///
/// Leaf categories (no subcategories) select directly and close. Categories with
/// subcategories navigate to the Step 2 [SubcategorySheet] instead, and show a
/// badge for the currently-selected subcategory if any.
///
/// Configurable for both call sites:
///  - [title] — sheet header ("Select Category" vs "Filter by Category").
///  - [allRowLabel] — when non-null, a pinned "All …" row is shown at the top
///    that returns [CategoryPickAll] (used by the Home filter to clear).
///  - [showManage] — whether the header pencil (→ Manage Categories) is shown.
class CategorySheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final String? selected;
  final String title;
  final String? allRowLabel;
  final bool showManage;

  /// When false the search field is hidden (short lists, e.g. the Home filter).
  final bool showSearch;

  /// When false, tapping a category with subcategories applies that category
  /// directly (no Step 2 sheet, no chevron) — used by the Home filter, which
  /// filters at the category level (parent + all its subcategories combined).
  final bool allowSubcategoryDrillDown;

  const CategorySheet({
    super.key,
    required this.categories,
    required this.selected,
    this.title = 'Select Category',
    this.allRowLabel,
    this.showManage = true,
    this.showSearch = true,
    this.allowSubcategoryDrillDown = true,
  });

  @override
  State<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<CategorySheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _leadingFor(CategoryModel c) =>
      categoryIconWidget(c.name, c.iconKey, c.emoji, kCatIconSize);

  /// Opens Step 2 for [cat]; if it resolves to a choice, closes this sheet too
  /// and propagates that result to the caller.
  Future<void> _openSubcategories(CategoryModel cat) async {
    final result = await showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SubcategorySheet(
        category: cat,
        selected: widget.selected,
        showManage: widget.showManage,
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Widget _subcategoryBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.goldDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold.withAlpha(120)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.gold,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Widget> _buildRows() {
    final q = _query.trim().toLowerCase();
    final specs = <RowSpec>[];

    // Optional pinned "All …" row (filter context): full-size icon, styled like
    // a top-level row, and selected when no filter is active. Clears the filter.
    if (widget.allRowLabel != null) {
      specs.add(
        RowSpec(
          label: widget.allRowLabel!,
          leading: const Icon(
            Icons.apps,
            size: kCatIconSize,
            color: AppTheme.gold,
          ),
          isSelected: widget.selected == null,
          onSelect: () => Navigator.of(context).pop(const CategoryPickAll()),
        ),
      );
    }

    for (final cat in widget.categories) {
      // Search matches the category name or any of its subcategory names.
      if (q.isNotEmpty) {
        final nameMatch = cat.name.toLowerCase().contains(q);
        final subMatch = cat.subcategories.any(
          (s) => s.toLowerCase().contains(q),
        );
        if (!nameMatch && !subMatch) continue;
      }

      if (cat.subcategories.isEmpty || !widget.allowSubcategoryDrillDown) {
        // Leaf, or drill-down disabled: selecting the category applies it
        // directly (no Step 2). What "applying a parent" means is up to the
        // caller — the Home filter expands it to the parent + subcategories.
        specs.add(
          RowSpec(
            label: cat.name,
            leading: _leadingFor(cat),
            isSelected: cat.name == widget.selected,
            onSelect: () =>
                Navigator.of(context).pop(CategoryPickValue(cat.name)),
          ),
        );
      } else {
        // Parent: navigate to Step 2. Highlight when the current selection
        // belongs here, and badge the specific subcategory if one is selected.
        final selectedSub = cat.subcategories.contains(widget.selected)
            ? widget.selected
            : null;
        final selectionInHere =
            widget.selected == cat.name || selectedSub != null;
        specs.add(
          RowSpec(
            label: cat.name,
            leading: _leadingFor(cat),
            isSelected: selectionInHere,
            showCheck: false,
            onSelect: () => _openSubcategories(cat),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedSub != null) _subcategoryBadge(selectedSub),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        );
      }
    }
    return pickerRows(specs);
  }

  @override
  Widget build(BuildContext context) {
    return PickerSheet(
      title: widget.title,
      fillHeight: true,
      showSearch: widget.showSearch,
      searchController: _searchController,
      onQueryChanged: (v) => setState(() => _query = v),
      rows: _buildRows(),
      action: widget.showManage
          ? IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Manage categories',
              color: AppTheme.gold,
              onPressed: () =>
                  Navigator.of(context).pop(const CategoryPickManage()),
            )
          : null,
    );
  }
}

// ── Step 2: subcategory picker ────────────────────────────────────────────────

/// Step 2 — subcategory picker for a category that has subcategories.
///
/// Only the subcategories are listed and selectable (there is no "parent only"
/// option); the user must pick a specific subcategory, or add a new one via the
/// header pencil (when [showManage]). Selecting pops with the chosen value, which
/// [CategorySheet] then uses to close Step 1 as well.
class SubcategorySheet extends StatelessWidget {
  final CategoryModel category;
  final String? selected;
  final bool showManage;

  const SubcategorySheet({
    super.key,
    required this.category,
    required this.selected,
    this.showManage = true,
  });

  @override
  Widget build(BuildContext context) {
    final parentOption = CategoryIcons.resolve(category.name, category.iconKey);
    final media = MediaQuery.of(context);
    // Near-full height: from just below the app bar to the bottom, matching the
    // Select Category sheet. Rows stay top-aligned; empty space below the last
    // row is expected when there are few subcategories.
    final height =
        media.size.height -
        media.viewPadding.top -
        kToolbarHeight -
        media.viewInsets.bottom;
    return GlassSheetBackground(
      child: SizedBox(
        height: height > 0 ? height : null,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Back button + category name as the title + optional manage pencil.
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showManage)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Manage categories',
                        color: AppTheme.gold,
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(const CategoryPickManage()),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  // Only subcategories are selectable — the user must pick a
                  // specific one. Each is a smaller, ~75%-opacity version of the
                  // parent's icon. Shares the same row builder as the other sheets.
                  children: pickerRows([
                    for (final sub in category.subcategories)
                      RowSpec(
                        label: sub,
                        leading: Icon(
                          parentOption.icon,
                          size: kSubIconSize,
                          color: parentOption.color.withAlpha(191),
                        ),
                        isSelected: selected == sub,
                        onSelect: () =>
                            Navigator.of(context).pop(CategoryPickValue(sub)),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
