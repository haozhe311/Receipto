import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/settings_provider.dart';
import 'package:receipto/screens/manage_categories_screen.dart';
import 'package:receipto/screens/manage_payment_methods_screen.dart';

/// Settings screen.
///
/// Section order:
///   1. AI PROVIDER  — provider toggle + API key input
///   2. PREFERENCES  — Manage Categories / Manage Payment Methods nav tiles
///   3. HOW TO GET AN API KEY — provider instructions
///   4. ABOUT        — app version
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    if (settings.hasApiKey) {
      _apiKeyController.text = settings.apiKey!;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 1. AI PROVIDER ──────────────────────────────────────────
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
                selected: {settings.aiProvider},
                onSelectionChanged: (selected) =>
                    settings.setAiProvider(selected.first),
              ),
              const SizedBox(height: 8),
              Text(
                switch (settings.aiProvider) {
                  'gemini' => 'Using Google Gemini 2.0 Flash-Lite',
                  'openai' => 'Using OpenAI GPT-4o Mini',
                  'groq'   =>
                    'Using Groq — Llama 3.1 8B Instant (Free, works in Malaysia)',
                  _        => '',
                },
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 20),

              // ── API KEY ──────────────────────────────────────────────────
              const _SectionHeader(title: 'API Key'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText:
                      '${switch (settings.aiProvider) { 'gemini' => 'Gemini', 'openai' => 'OpenAI', _ => 'Groq' }} API Key',
                  hintText: 'Paste your API key here',
                  helperText: settings.aiProvider == 'groq'
                      ? 'Get your free API key at console.groq.com'
                      : null,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveApiKey,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Key'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: settings.hasApiKey ? _clearApiKey : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    settings.hasApiKey
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    size: 16,
                    color: settings.hasApiKey ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    settings.hasApiKey
                        ? 'API key is saved securely on this device'
                        : 'No API key set — chatbot will not work',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: settings.hasApiKey
                              ? Colors.green
                              : Colors.orange,
                        ),
                  ),
                ],
              ),

              // Privacy notice
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
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
                        'Your API key is stored securely on this device using '
                        'encrypted storage. It is never sent to any server '
                        'other than the AI provider you selected.',
                        style:
                            TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 2. PREFERENCES ───────────────────────────────────────────
              const _SectionHeader(title: 'Preferences'),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.grid_view_rounded,
                title: 'Manage Categories',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageCategoriesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.credit_card,
                title: 'Manage Payment Methods',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManagePaymentMethodsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 3. HOW TO GET AN API KEY ─────────────────────────────────
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

              // ── 4. ABOUT ─────────────────────────────────────────────────
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

  void _saveApiKey() {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    context.read<SettingsProvider>().setApiKey(key);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API key saved securely'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearApiKey() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear API Key'),
        content: const Text(
          'Are you sure you want to remove the stored API key? '
          'The AI chatbot will stop working until a new key is set.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<SettingsProvider>().clearApiKey();
              _apiKeyController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API key removed')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
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
              color: Color(0xFF555577),
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
