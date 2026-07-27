import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/settings_provider.dart';
import 'package:receipto/widgets/app_page_route.dart';
import 'package:receipto/screens/backup_screen.dart';
import 'package:receipto/screens/budgets_screen.dart';
import 'package:receipto/screens/goals_screen.dart';
import 'package:receipto/screens/manage_categories_screen.dart';
import 'package:receipto/screens/recurring_screen.dart';
import 'package:receipto/screens/wallets_screen.dart';

/// Settings screen.
///
/// Section order:
///   1. AI PROVIDER  — provider toggle + per-provider key list + add-key field
///   2. PREFERENCES  — Manage Categories / Manage Payment Methods nav tiles
///   3. HOW TO GET AN API KEY — provider instructions
///   4. ABOUT        — app version
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _addKeyController = TextEditingController();
  bool _obscureNewKey = true;
  String? _keyError;

  static const Map<String, String> _prefixes = {
    'groq':   'gsk_',
    'openai': 'sk-',
    'gemini': 'AIza',
  };

  static const Map<String, String> _providerLabels = {
    'groq':   'Groq',
    'openai': 'OpenAI',
    'gemini': 'Gemini',
  };

  @override
  void dispose() {
    _addKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final provider = settings.aiProvider;
          final keys = settings.keysFor(provider);
          final activeIdx = settings.activeIndexFor(provider);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
            children: [
              // ══════════ MANAGE ══════════
              const _GroupHeader(title: 'Manage'),
              const SizedBox(height: 12),
              _NavTile(
                icon: Icons.grid_view_rounded,
                title: 'Manage Categories',
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(
                    builder: (_) => const ManageCategoriesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budgets',
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(builder: (_) => const BudgetsScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.savings_outlined,
                title: 'Savings Goals',
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(builder: (_) => const GoalsScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.autorenew,
                title: 'Recurring Transactions',
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(builder: (_) => const RecurringScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.account_balance_wallet,
                title: 'Wallets & Balances',
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(builder: (_) => const WalletsScreen()),
                ),
              ),
              const SizedBox(height: 28),

              // ══════════ APP SETTINGS ══════════
              const _GroupHeader(title: 'App settings'),
              const SizedBox(height: 16),

              // ── AI PROVIDER ────────────────────────────────────────────
              const _SectionHeader(title: 'AI Provider'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'gemini',
                    label: Text('Gemini'),
                    icon: Icon(Icons.auto_awesome),
                  ),
                  ButtonSegment(
                    value: 'openai',
                    label: Text('OpenAI'),
                    icon: Icon(Icons.psychology),
                  ),
                  ButtonSegment(
                    value: 'groq',
                    label: Text('Groq (Free & Fast)'),
                    icon: Icon(Icons.bolt),
                  ),
                ],
                selected: {provider},
                onSelectionChanged: (selected) {
                  settings.setAiProvider(selected.first);
                  // Clear the add-key field when switching providers.
                  _addKeyController.clear();
                  setState(() => _obscureNewKey = true);
                },
              ),
              const SizedBox(height: 8),
              Text(
                switch (provider) {
                  'gemini' => 'Using Google Gemini 2.0 Flash-Lite',
                  'openai' => 'Using OpenAI GPT-4o Mini',
                  'groq'   =>
                    'Using Groq (Free, works in Malaysia)',
                  _        => '',
                },
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),

              // Groq model selector
              if (provider == 'groq') ...[
                const SizedBox(height: 12),
                Text(
                  'Groq model',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: SettingsProvider.groqLlama,
                      label: Text('Llama 3.1 8B'),
                    ),
                    ButtonSegment(
                      value: SettingsProvider.groqGptOss,
                      label: Text('GPT OSS 120B'),
                    ),
                  ],
                  selected: {settings.groqModel},
                  onSelectionChanged: (selected) =>
                      settings.setGroqModel(selected.first),
                ),
                const SizedBox(height: 6),
                Text(
                  settings.groqModel == SettingsProvider.groqGptOss
                      ? 'GPT OSS 120B — larger, more accurate, a little slower'
                      : 'Llama 3.1 8B — fastest, lightweight',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
              const SizedBox(height: 20),

              // ── API KEYS ───────────────────────────────────────────────
              const _SectionHeader(title: 'API Keys'),
              const SizedBox(height: 8),

              // Key list (empty state or rows)
              if (keys.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.glassRowFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.glassBorderSoft),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: AppTheme.onGlassFaint,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No API key saved — chatbot will not work',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < keys.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _KeyRow(
                        keyValue: keys[i],
                        isActive: i == activeIdx,
                        onActivate: () => settings.setActiveKey(provider, i),
                        onDelete: () => _confirmDelete(context, settings, provider, i),
                      ),
                    ],
                  ],
                ),

              // ── Add new key ────────────────────────────────────────────
              const SizedBox(height: 16),
              TextFormField(
                controller: _addKeyController,
                obscureText: _obscureNewKey,
                onChanged: (_) {
                  if (_keyError != null) {
                    setState(() => _keyError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText:
                      'New ${_providerLabels[provider] ?? 'Provider'} API Key',
                  hintText: switch (provider) {
                    'groq'   => 'Paste your Groq key (starts with gsk_)',
                    'openai' => 'Paste your OpenAI key (starts with sk-)',
                    _        => 'Paste your Gemini key (starts with AIza)',
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewKey
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNewKey = !_obscureNewKey),
                  ),
                ),
              ),
              if (_keyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    _keyError!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _saveNewKey(context, settings),
                  icon: const Icon(Icons.add),
                  label: const Text('Save Key'),
                ),
              ),

              // Privacy notice
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.glassRowFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassBorderSoft),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 18,
                      color: AppTheme.gold.withAlpha(200),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'API keys are stored on this device and never sent '
                        'to any server other than the AI provider you selected.',
                        style:
                            TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── HOW TO GET AN API KEY ──────────────────────────────────
              const _SectionHeader(title: 'How to get an API key'),
              const SizedBox(height: 8),
              _InstructionCard(
                icon: Icons.auto_awesome,
                title: 'Google Gemini',
                steps: const [
                  'Go to ai.google.dev',
                  'Sign in with your Google account',
                  'Click "Get API key" in Google AI Studio',
                  'Create a new API key and copy it',
                ],
              ),
              const SizedBox(height: 12),
              _InstructionCard(
                icon: Icons.psychology,
                title: 'OpenAI',
                steps: const [
                  'Go to platform.openai.com',
                  'Sign in or create an account',
                  'Navigate to API Keys section',
                  'Create a new secret key and copy it',
                ],
              ),
              const SizedBox(height: 12),
              _InstructionCard(
                icon: Icons.bolt,
                title: 'Groq (Free — Recommended for Malaysia)',
                steps: const [
                  'Go to console.groq.com',
                  'Sign up for a free account',
                  'Navigate to API Keys section',
                  'Create a new key and copy it',
                  'Free tier: 14,400 requests/day, no credit card needed',
                ],
              ),
              const SizedBox(height: 24),

              // ── DATA ───────────────────────────────────────────────────
              const _SectionHeader(title: 'Data'),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.cloud_outlined,
                title: 'Backup & Restore',
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(builder: (_) => const BackupScreen()),
                ),
              ),
              const SizedBox(height: 24),

              // ── ABOUT ──────────────────────────────────────────────────
              const _SectionHeader(title: 'About'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'FYP1 Proof of Concept',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Intelligent Personal Finance Management System',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _saveNewKey(BuildContext context, SettingsProvider settings) {
    final key = _addKeyController.text.trim();
    final provider = settings.aiProvider;

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Prefix validation
    final expectedPrefix = _prefixes[provider] ?? '';
    if (!key.startsWith(expectedPrefix)) {
      final label = _providerLabels[provider] ?? provider;
      // Use "an" before vowels, "a" before consonants.
      final article = 'aeiouAEIOU'.contains(label[0]) ? 'an' : 'a';
      setState(() {
        _keyError =
            "This doesn't look like $article $label key. "
            "$label keys start with $expectedPrefix";
      });
      return;
    }

    settings.addKey(provider, key);
    _addKeyController.clear();
    setState(() {
      _obscureNewKey = true;
      _keyError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API key saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    SettingsProvider settings,
    String provider,
    int index,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this API key?'),
        content: const Text('This cannot be undone.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              settings.deleteKey(provider, index);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Key row ───────────────────────────────────────────────────────────────────

/// A card row displaying one API key with reveal / copy / delete actions.
class _KeyRow extends StatefulWidget {
  final String keyValue;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  const _KeyRow({
    required this.keyValue,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  @override
  State<_KeyRow> createState() => _KeyRowState();
}

class _KeyRowState extends State<_KeyRow> {
  bool _revealed = false;
  bool _copied = false;

  static String _mask(String key) {
    if (key.length < 12) { return '••••••••'; }
    return '${key.substring(0, 8)}••••••••••••••••${key.substring(key.length - 4)}';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.keyValue));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) { setState(() => _copied = false); }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _revealed ? widget.keyValue : _mask(widget.keyValue);

    return GestureDetector(
      onTap: widget.onActivate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.glassRowFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isActive ? AppTheme.gold : AppTheme.border,
            width: widget.isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Reveal toggle
            GestureDetector(
              onTap: () => setState(() => _revealed = !_revealed),
              child: Icon(
                _revealed ? Icons.visibility : Icons.visibility_off,
                size: 18,
                color: _revealed ? AppTheme.gold : AppTheme.onGlassFaint,
              ),
            ),
            const SizedBox(width: 10),

            // Key text + ACTIVE badge
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        color: _revealed
                            ? AppTheme.gold
                            : const Color(0xFFC0C0D8),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.goldDark,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.gold),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Copy button
            GestureDetector(
              onTap: _copy,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  _copied ? Icons.check : Icons.copy,
                  size: 18,
                  color: _copied
                      ? const Color(0xFF4CAF50)
                      : AppTheme.onGlassFaint,
                ),
              ),
            ),

            // Delete button
            GestureDetector(
              onTap: widget.onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

/// Gold uppercase section header.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.gold,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// A prominent header separating the two top-level Settings groups
/// ("Manage" vs "App settings"), visually distinct from [_SectionHeader].
class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: AppTheme.border, thickness: 1)),
      ],
    );
  }
}

/// A tappable card row that navigates to a sub-screen.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.glassRowFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.glassBorderSoft),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.gold),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.onGlassFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// A card with step-by-step instructions for obtaining an API key.
class _InstructionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> steps;

  const _InstructionCard({
    required this.icon,
    required this.title,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...steps.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
