import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/widgets/category_icon_grid.dart';

/// Detail screen for a single category: rename it, change its icon/colour,
/// manage its subcategories, or delete it.
class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;

  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late String _name; // tracks the current name across renames
  late final TextEditingController _nameController;
  late String _iconKey;

  bool get _isProtected => _name == CategoryProvider.protectedName;

  @override
  void initState() {
    super.initState();
    _name = widget.categoryName;
    final cat = context.read<CategoryProvider>().byName(_name);
    _nameController = TextEditingController(text: cat?.name ?? _name);
    _iconKey = cat?.iconKey ?? CategoryIcons.resolve(_name, cat?.iconKey).key;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  /// Persists a pending rename. Returns false if the name was rejected.
  Future<bool> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName == _name) return true;
    if (newName.isEmpty) {
      _nameController.text = _name;
      return true;
    }
    final ok = await context.read<CategoryProvider>().renameCategory(
          _name,
          newName,
        );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That category name is already in use'),
            backgroundColor: Colors.orange,
          ),
        );
        _nameController.text = _name;
      }
      return false;
    }
    setState(() => _name = newName);
    return true;
  }

  void _selectIcon(String key) {
    setState(() => _iconKey = key);
    context.read<CategoryProvider>().setIcon(_name, key);
  }

  void _confirmDeleteCategory() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Delete "$_name"? Existing transactions keep this category name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              Navigator.of(ctx).pop();
              context.read<CategoryProvider>().deleteCategory(_name);
              navigator.pop();
            },
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addSubcategory() {
    showDialog<void>(
      context: context,
      builder: (_) => _AddSubcategoryDialog(
        onSave: (value) =>
            context.read<CategoryProvider>().addSubcategory(_name, value),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final cat = provider.byName(_name);
    // The category was deleted from under us.
    if (cat == null) return const Scaffold(body: SizedBox.shrink());

    final option = CategoryIcons.resolve(cat.name, _iconKey);
    final subs = cat.subcategories;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveName();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(cat.name),
          actions: [
            if (!_isProtected)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete category',
                onPressed: _confirmDeleteCategory,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Icon preview with pencil badge
            Center(child: _iconPreview(option)),
            const SizedBox(height: 24),

            // Name
            TextField(
              controller: _nameController,
              enabled: !_isProtected,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: _isProtected
                    ? '"${CategoryProvider.protectedName}" cannot be renamed'
                    : null,
              ),
              onEditingComplete: _saveName,
            ),
            const SizedBox(height: 24),

            // Icon (each swatch is a fixed icon + colour pairing)
            Text(
              'Icon',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            CategoryIconGrid(
              selectedKey: _iconKey,
              onSelected: _selectIcon,
            ),
            const SizedBox(height: 28),

            // Subcategories
            Text(
              'Subcategories',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              subs.isEmpty
                  ? 'No subcategories yet.'
                  : '${subs.length} subcategor${subs.length == 1 ? 'y' : 'ies'}',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final sub in subs) _subcategoryRow(sub),
            const SizedBox(height: 4),
            _addSubcategoryButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Live preview of the selected swatch. Non-interactive: the pencil badge is
  /// only a hint that the icon is editable — the single source of selection is
  /// the inline "Icon" grid below.
  Widget _iconPreview(CategoryIconOption option) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: option.color.withAlpha(38),
              border: Border.all(color: option.color.withAlpha(120), width: 2),
            ),
            child: Icon(option.icon, color: option.color, size: 44),
          ),
          Positioned(
            right: 0,
            bottom: 4,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.gold,
                border: Border.all(color: AppTheme.background, width: 2),
              ),
              child: const Icon(Icons.edit, size: 15, color: Color(0xFF1A1A00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subcategoryRow(String sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sub,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: const Color(0xFFFF6B6B),
            tooltip: 'Delete subcategory',
            onPressed: () =>
                context.read<CategoryProvider>().deleteSubcategory(_name, sub),
          ),
        ],
      ),
    );
  }

  Widget _addSubcategoryButton() {
    return CustomPaint(
      painter: const DashedBorderPainter(color: AppTheme.border),
      child: InkWell(
        onTap: _addSubcategory,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 18, color: AppTheme.gold),
              const SizedBox(width: 6),
              Text(
                'Add Subcategory',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple text-input dialog for a new subcategory name.
class _AddSubcategoryDialog extends StatefulWidget {
  final ValueChanged<String> onSave;

  const _AddSubcategoryDialog({required this.onSave});

  @override
  State<_AddSubcategoryDialog> createState() => _AddSubcategoryDialogState();
}

class _AddSubcategoryDialogState extends State<_AddSubcategoryDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter a subcategory name');
      return;
    }
    final navigator = Navigator.of(context);
    widget.onSave(value);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Subcategory'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Subcategory name',
          hintText: 'e.g. Groceries',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
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
