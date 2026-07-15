import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/screens/category_detail_screen.dart';
import 'package:receipto/widgets/category_icon_grid.dart';

/// Lists categories and opens each one's detail screen.
///
/// Navigated to from the Settings screen via a nav tile.
class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: Consumer<CategoryProvider>(
        builder: (context, provider, _) {
          final categories = provider.categories;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < categories.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 0,
                          color: AppTheme.border,
                        ),
                      _CategoryRow(category: categories[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Add category button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddDialog(context, provider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Category'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, CategoryProvider provider) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddCategoryDialog(
        onSave: (name, iconKey) => provider.addCategory(name, iconKey),
      ),
    );
  }
}

/// A single category row: icon, name, subcategory count, and a chevron.
/// The protected "Others" category shows a lock and is not tappable.
class _CategoryRow extends StatelessWidget {
  final CategoryModel category;

  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final option = CategoryIcons.resolve(category.name, category.iconKey);
    final isProtected = category.name == CategoryProvider.protectedName;
    final count = category.subcategories.length;

    return InkWell(
      onTap: isProtected
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CategoryDetailScreen(categoryName: category.name),
                ),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: option.color.withAlpha(38),
              ),
              child: Icon(option.icon, color: option.color, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'No subcategories'
                        : '$count subcategor${count == 1 ? 'y' : 'ies'}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isProtected)
              Icon(Icons.lock, size: 16, color: AppTheme.textMuted)
            else
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF555577),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for creating a category: name + an icon/colour swatch.
class _AddCategoryDialog extends StatefulWidget {
  final void Function(String name, String iconKey) onSave;

  const _AddCategoryDialog({required this.onSave});

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameController = TextEditingController();
  String _iconKey = CategoryIcons.presets.first.key;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a category name');
      return;
    }
    final navigator = Navigator.of(context);
    widget.onSave(name, _iconKey);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Category name',
                hintText: 'e.g. Groceries',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 20),
            Text('Icon & color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              width: 280,
              child: CategoryIconGrid(
                selectedKey: _iconKey,
                onSelected: (key) => setState(() => _iconKey = key),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
