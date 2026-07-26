import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/category_glyphs.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/widgets/category_icon_grid.dart' show DashedBorderPainter;
import 'package:receipto/widgets/category_pickers.dart';

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
  late String? _iconKey;
  late int _colorValue;

  bool get _isProtected => _name == CategoryProvider.protectedName;

  @override
  void initState() {
    super.initState();
    _name = widget.categoryName;
    final cat = context.read<CategoryProvider>().byName(_name);
    _nameController = TextEditingController(text: cat?.name ?? _name);
    _iconKey = cat?.iconKey;
    _colorValue = CategoryGlyphs.categoryVisual(
      name: _name,
      iconKey: cat?.iconKey,
      colorValue: cat?.colorValue,
    ).color.toARGB32();
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

  void _selectColor(int colorValue) {
    setState(() => _colorValue = colorValue);
    context.read<CategoryProvider>().setColor(_name, colorValue);
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
        parentColor: Color(_colorValue),
        onSave: (name, iconKey) => context
            .read<CategoryProvider>()
            .addSubcategory(_name, name, iconKey: iconKey),
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

    final subs = cat.subcategories;
    final color = Color(_colorValue);

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
            Center(child: _iconPreview(color)),
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

            // Icon + colour are chosen independently. Editable for every
            // category except the protected "Others", which stays fixed.
            if (_isProtected)
              Text(
                '"${CategoryProvider.protectedName}" keeps a fixed icon.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              )
            else ...[
              Text('Icon', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              CategoryIconPickerGrid(
                selectedKey: _iconKey,
                onSelected: _selectIcon,
              ),
              const SizedBox(height: 24),
              Text('Colour', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              ColorPickerGrid(
                selectedValue: _colorValue,
                onSelected: _selectColor,
              ),
            ],
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
            for (final sub in subs) _subcategoryRow(sub, color),
            const SizedBox(height: 4),
            _addSubcategoryButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Live preview of the category's icon on its chosen background colour.
  Widget _iconPreview(Color color) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        children: [
          CategoryIconBadge(
            assetPath: CategoryGlyphs.categoryAssetFor(_iconKey),
            background: color,
            size: 96,
          ),
          if (!_isProtected)
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
                child: const Icon(Icons.edit, size: 15, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _subcategoryRow(SubcategoryModel sub, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppTheme.glassRowFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorderSoft),
      ),
      child: Row(
        children: [
          CategoryIconBadge(
            assetPath: CategoryGlyphs.subcategoryAssetFor(sub.iconKey),
            background: color,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sub.name,
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
            onPressed: () => context
                .read<CategoryProvider>()
                .deleteSubcategory(_name, sub.name),
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

/// Dialog for a new subcategory: a name plus an icon picked from the 45
/// subcategory glyphs. No colour — subcategories inherit the parent's colour,
/// shown live in the preview badge.
class _AddSubcategoryDialog extends StatefulWidget {
  final Color parentColor;
  final void Function(String name, String? iconKey) onSave;

  const _AddSubcategoryDialog({required this.parentColor, required this.onSave});

  @override
  State<_AddSubcategoryDialog> createState() => _AddSubcategoryDialogState();
}

class _AddSubcategoryDialogState extends State<_AddSubcategoryDialog> {
  final _controller = TextEditingController();
  String? _iconKey;
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
    widget.onSave(value, _iconKey);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Subcategory'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIconBadge(
                  assetPath: CategoryGlyphs.subcategoryAssetFor(_iconKey),
                  background: widget.parentColor,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Groceries',
                      errorText: _error,
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Icon', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: SubcategoryIconPickerGrid(
                  selectedKey: _iconKey,
                  onSelected: (key) => setState(() => _iconKey = key),
                ),
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
