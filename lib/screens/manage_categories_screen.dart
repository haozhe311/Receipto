import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/providers/category_provider.dart';

/// Full-page screen for adding and deleting transaction categories.
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
              // Category list
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
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 0,
                          color: AppTheme.border,
                        ),
                      _CategoryRow(
                        category: categories[i],
                        onDelete: categories[i].name == 'Others'
                            ? null
                            : () => provider.deleteCategory(categories[i].name),
                      ),
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
    final nameController = TextEditingController();
    final emojiController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'e.g. Fitness, Travel',
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 20,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) { return 'Name cannot be empty'; }
                  if (provider.categoryNames.any(
                    (n) => n.toLowerCase() == trimmed.toLowerCase(),
                  )) {
                    return 'Category already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emojiController,
                decoration: const InputDecoration(
                  labelText: 'Emoji icon',
                  hintText: 'e.g. 🏋️, ✈️, 📚',
                  counterText: '',
                ),
                maxLength: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an emoji';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) { return; }
              await provider.addCategory(
                nameController.text.trim(),
                emojiController.text.trim(),
              );
              if (ctx.mounted) { Navigator.of(ctx).pop(); }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      emojiController.dispose();
    });
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onDelete;

  const _CategoryRow({required this.category, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isBuiltIn = AppConstants.categoryIcons.containsKey(category.name);
    final builtInIcon = AppConstants.categoryIcons[category.name];
    final builtInColor =
        AppConstants.categoryColors[category.name] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: isBuiltIn
                ? Icon(builtInIcon, color: builtInColor, size: 20)
                : Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: const Color(0xFFFF6B6B),
              tooltip: 'Delete category',
            )
          else
            const Icon(Icons.lock_outline, size: 16, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
